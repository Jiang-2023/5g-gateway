/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t; 
typedef bit<32> ip4Addr_t;

header new_ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr; 
    bit<16>   etherType;
    bit<8>    protocolType; // 用于识别数据包类型的字段
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
    bit<8>  unitId;
    bit<8>  functionCode;
}

header profinetIRT_t {
    /* profinet IRT */
    bit<4>  frameID;
    bit<4>  frameType;
    bit<16> datalength;
    bit<8>  telegramNumber;
}

struct metadata_t {
    bit<1> isModbus;
    bit<1> isProfinet;
    bit<8> nhop_index;
}

struct headers {
    ethernet_t      ethernet;
    new_ethernet_t  new_ethernet;
    ipv4_t          ipv4;
    ipv6_t          ipv6;
    tcp_t           tcp;
    modbusTCP_t     modbus;
    profinetIRT_t   profinet;
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
        transition select(hdr.ethernet.etherType){
            0x0800: ipv4;
            0x86DD: ipv6;
            0x8892: profinetIRT;
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
    state ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
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
        meta.isModbus = 1;
        transition accept;
    }
   
    state profinetIRT {
        packet.extract(hdr.profinet);
        meta.isProfinet = 1;
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

    action add_new_ethernet(macAddr_t srcAddr, macAddr_t dstAddr, bit<16> etherType, bit<8> protocolType) {
        hdr.new_ethernet.srcAddr = srcAddr;
        hdr.new_ethernet.dstAddr = dstAddr;
        hdr.new_ethernet.etherType = etherType;
        hdr.new_ethernet.protocolType = protocolType;
    }

    action ipv4_replace(ip4Addr_t srcAddr, ip4Addr_t dstAddr){
        hdr.ipv4.srcAddr = srcAddr;
        hdr.ipv4.dstAddr = dstAddr;
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
            ipv4_replace;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    table ipv4_lpm {
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

        if (meta.isModbus) {
            add_new_ethernet(hdr.ethernet.srcAddr, hdr.ethernet.dstAddr, 0x88B5, 0x01); // MODbusTCP类型标识
        } else if (meta.isProfinet) {
            add_new_ethernet(hdr.ethernet.srcAddr, hdr.ethernet.dstAddr, 0x88B5, 0x02); // Profinet类型标识
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
        packet.emit(hdr.new_ethernet); // Emit new Ethernet header with protocol type
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
        if (meta.isModbus) {
            packet.emit(hdr.modbus);
        } else if (meta.isProfinet) {
            packet.emit(hdr.profinet);
        }
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
