/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

// 常量定义
const bit<16> TYPE_IPV4 = 0x0800; // IPv4 协议类型
const bit<8> PROTOCOL_ICMP = 0x01; // ICMP 协议号

// 接口 MAC 地址
const macAddr_t ETH1_MAC_ADDR = 0x1285befffe54; // eth1 的 MAC 地址
const macAddr_t USB0_MAC_ADDR = 0x068133020d42; // usb0 的 MAC 地址

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

// 以太网头部
header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

// IPv4 头部
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

// ICMP 头部
header icmp_t {
    bit<8>    type;
    bit<8>    code;
    bit<16>   checksum;
    bit<16>   identifier;
    bit<16>   sequence_number;
}

// 元数据
struct metadata {
    /* 可用于存储中间处理信息 */
    bit<8> nhop_index;
}

// 头部结构
struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    icmp_t       icmp;
}

/*************************************************************************
*********************** P A R S E R  *************************************
*************************************************************************/

// 数据包解析器
parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        // 提取以太网头
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4; // 如果是 IPv4 数据包，转到 parse_ipv4 状态
            default: accept; // 其他情况接受数据包
        }
    }

    state parse_ipv4 {
        // 提取 IPv4 头
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            PROTOCOL_ICMP: parse_icmp; // 如果是 ICMP 数据包，转到 parse_icmp 状态
            default: accept; // 其他情况接受数据包
        }
    }

    state parse_icmp {
        // 提取 ICMP 头
        packet.extract(hdr.icmp);
        transition accept; // 接受数据包
    }
}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

// 校验和验证控制块
control MyVerifyChecksum(inout headers hdr, inout metadata meta) {  
    apply {
        // 可以在这里添加校验和验证逻辑
    }
}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

// 入站处理控制块
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    // 转发动作
    action forward(macAddr_t dstAddr, egressSpec_t port) {
        // 更新以太网头的目标和源 MAC 地址
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ethernet.srcAddr = USB0_MAC_ADDR; // 从 USB0 发送数据包
        standard_metadata.egress_spec = port; // 设置出口端口
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1; // 减少 TTL
    }

    // 丢弃数据包
    action drop() {
        mark_to_drop(standard_metadata);
    }

    // 定义转发表
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm; // 使用最长前缀匹配
        }
        actions = {
            forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = NoAction(); // 默认不做任何动作
    }

    apply {
        // 仅处理来自指定源地址的 ICMP 数据包
        if (hdr.ipv4.isValid() && hdr.icmp.isValid() && hdr.ipv4.srcAddr == 192.168.137.1) {
            ipv4_lpm.apply(); // 应用转发表
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

// 出站处理控制块
control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { 
        // 可以在这里添加出站处理逻辑
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

// 校验和计算控制块
control MyComputeChecksum(inout headers hdr, inout metadata meta) {
     apply {
        update_checksum(
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

// 数据包封装器
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        // 重新封装以太网和 IPv4 头
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.icmp);
    }
}

/*************************************************************************
***********************  S W I T C H  ************************************
*************************************************************************/

// 交换机架构
V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
