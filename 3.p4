/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x0800;         // IPv4
const bit<16> TYPE_IPV6 = 0x86DD;         // IPv6

//工业控制协议
//A类-准RT
//const bit<16> TYPE_ETHERNET_IP = 0x88B5;     // EtherNet/IP
const bit<16> TYPE_MODBUS_TCP = 0x88B6;  // Modbus TCP/UDP
//const bit<16> TYPE_EAP = 0x88A4;             // EtherCAT Automation Protocol (EAP)

//B类-RT
const bit<16> TYPE_PROFINET_RT = 0x8892;     // ProfiNET (RT)
//const bit<16> TYPE_POWER_LINK = 0x88AB;      // Power Link

//C类-IRT
//const bit<16> TYPE_PROFINET_IRT = 0x88F7;    // ProfiNET (IRT)
//const bit<16> TYPE_CC_LINK_IE = 0x890F;      // CC-Link IE
//const bit<16> TYPE_SERCOS_III = 0x88CD;      // Sercos III
//const bit<16> TYPE_ETHERCAT = 0x88A4;        // EtherCAT


/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header new_ethernet_t{
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header ipv6_t {
    bit<4>    version;
    bit<8>    trafficClass;
    bit<20>   flowLabel;
    bit<16>   payloadLen;
    bit<8>    nextHeader;
    bit<8>    hopLimit;
    bit<128>  srcAddr;
    bit<128>  dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNom;
    bit<32> ackNom;
    bit<4>  dataOffset;
    bit<4>  flags;
    bit<16> windowSize;
    bit<16> checksum;
    bit<16> urgentPtr;
}

header modbusTCP_t {
    bit<16> transactionId;
    bit<16> protocolId;
    bit<16> length;
    bit<8> unitId;
    bit<8> functionCode;
}

header profinetRT_t {
    bit<4>  frameID;
    bit<4>  frameType;
    bit<16> datalength;
    bit<8>  telegramNumber;
}

struct metadata {
    /* empty */
}


struct headers {
    new_ethernet_t  new_ethernet;
    ethernet_t      ethernet;
    ipv4_t          ipv4;
    ipv6_t          ipv6;
    tcp_t           tcp;
    modbusTCP_t     modbus;
    profinetRT_t   profinet;
}


/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        packet.extract(hdr.ethernet);  
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: ipv4;           
            TYPE_IPV6: ipv6;           
            TYPE_MODBUS_TCP: modbusTCP;  
            TYPE_PROFINET_RT: profinet;  
            default: accept;
        }
    }

    state ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            0x06: tcp;
            default: accept;
        }
    }

    state ipv6 {
        packet.extract(hdr.ipv6);
        transition select(hdr.ipv6.nextHeader) {
            0x06: tcp;
            default: accept;
        }
    }

    state tcp {
        packet.extract(hdr.tcp);
        transition select(hdr.tcp.dstPort) {
            5020: modbusTCP;
            default: accept;
        }
    }

    state modbusTCP {
        packet.extract(hdr.modbus);
        transition accept;
    }

    state profinet {
        packet.extract(hdr.profinet);
        transition accept;
    }
}



/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {  
    apply { }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    // 地址映射动作
    action address_mapping() {
        // 翻转原始以太网头部的 srcAddr 和 dstAddr
        hdr.new_ethernet.srcAddr = hdr.ethernet.dstAddr;  // 将原始的目的地址作为新的源地址
        hdr.new_ethernet.dstAddr = hdr.ethernet.srcAddr;  // 将原始的源地址作为新的目的地址
        
        // 使用新的 EtherType 值来区分不同的工业互联网协议
        if (hdr.modbus.isValid()) {
            hdr.new_ethernet.etherType = TYPE_MODBUS_TCP;  // 对于 Modbus TCP 协议，设置特定的 EtherType
        } else if (hdr.profinet.isValid()) {
            hdr.new_ethernet.etherType = TYPE_PROFINET_RT; // 对于 Profinet RT 协议，设置特定的 EtherType
        }
    }

   action drop() {
        mark_to_drop(standard_metadata);
    }

    action ip_forward(macAddr_t dstAddr, egressSpec_t port) {
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        standard_metadata.egress_spec = port;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }


    table replace_table {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            address_mapping;  // 应用地址映射动作
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }
    table ipv4_lpm{
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ip_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    apply {
        replace_table.apply();
        if (hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	          hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}


/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        // 输出新的以太网头部
        packet.emit(hdr.new_ethernet);
        //parsed headers have to be added again into the packet.
        packet.emit(hdr.ethernet);  // 发射原始以太网头部
        packet.emit(hdr.ipv4);  // 发射 IPv4 头部
        packet.emit(hdr.tcp);  // 发射 TCP 头部
        packet.emit(hdr.modbus);  // 发射 Modbus TCP 头部
        packet.emit(hdr.profinet);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

//switch architecture
V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
