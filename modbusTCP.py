# _*_ coding: utf-8 _*_
# 模拟TCP从站设备
from pymodbus.server import StartTcpServer
from pymodbus.device import ModbusDeviceIdentification
from pymodbus.datastore import ModbusSequentialDataBlock, ModbusSlaveContext, ModbusServerContext
from pymodbus.transaction import ModbusRtuFramer, ModbusBinaryFramer
import logging

# # 创建数据存储块，这里我们创建了一个包含100个寄存器的数据块
# store = ModbusSlaveContext(
#     di = ModbusSequentialDataBlock(0, [0]*100),   # 离散输入
#     co = ModbusSequentialDataBlock(0, [0]*100),   # 线圈的含义是开关量，输入是离散量，0和1
#     hr = ModbusSequentialDataBlock(0, [17]*100),   # 保持寄存器
#     ir = ModbusSequentialDataBlock(0, [0]*100))
#
# context = ModbusServerContext(slaves=store, single=True)

def run_modbus_server():

    # 一次创建多个从站 #
    num_devices = 20

    # 创建多个从站的数据存储块和上下文
    contexts = {}
    for device_id in range(1, num_devices + 1):
        store = ModbusSlaveContext(
            di=ModbusSequentialDataBlock(0, [0] * 100),        # 离散输入
            co=ModbusSequentialDataBlock(0, [0] * 100),        # 线圈的含义是开关量，输入是离散量，0和1
            hr=ModbusSequentialDataBlock(0, [0] * 100),        # 保持寄存器
            ir=ModbusSequentialDataBlock(0, [0] * 100))        # 输入寄存器
        contexts[device_id] = store
    context = ModbusServerContext(slaves=contexts, single=False)

    # 启动Modbus TCP服务器，默认端口为5020
    StartTcpServer(context=context, address=("200.100.1.2", 5020))

if __name__ == "__main__":
    run_modbus_server()
