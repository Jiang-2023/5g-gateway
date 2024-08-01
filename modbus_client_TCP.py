# _*_ coding: utf-8 _*_
from pymodbus.client import ModbusTcpClient, ModbusSerialClient
# from atexit import register
# from pymodbus.transaction import ModbusRtuFramer
# import serial
# import modbus_tk.defines as cst
# from modbus_tk import modbus_rtu

def read_coil(address,count,slave):
    result = client.read_coils(address=address, count=count, slave=slave)
    if result.isError():
        print("读取错误: %s" % result)
    else:
        print("从机%d,地址%d-%d的线圈值: %s" % (slave, address, address+count-1, result.bits[:count]))

def read_discrete_input(address,count,slave):
    result = client.read_discrete_inputs(address=address, count=count, slave=slave)
    if result.isError():
        print("读取错误: %s" % result)
    else:
        print("从机%d,地址%d-%d的离散输入: %s" % (slave, address, address+count-1, result.bits[:count]))

def read_holding_register(address,count,slave):
    result = client.read_holding_registers(address=address, count=count, slave=slave)
    if result.isError():
        print("读取错误: %s" % result)
    else:
        print("从机%d,地址%d-%d的保持寄存器: %s" % (slave, address, address+count-1, result.registers))

def read_input_register(address,count,slave):
    result = client.read_input_registers(address=address, count=count, slave=slave)
    if result.isError():
        print("读取错误: %s" % result)
    else:
        print("从机%d,地址%d-%d的输入寄存器: %s" % (slave, address, address+count-1, result.registers))

def write_coil(address,value,slave):  # 写单个线圈
    result = client.write_coil(address=address, value=value, slave=slave)
    if result.isError():
        print("写入错误: %s" % result)
    else:
        print("写入从机%d,地址%d的线圈值: %s" % (slave, address, value))

def write_register(address,value,slave):   # 写单个寄存器
    result = client.write_register(address=address, value=value, slave=slave)
    if result.isError():
        print("写入错误: %s" % result)
    else:
        print("写入从机%d,地址%d的保持寄存器: %s" % (slave, address, value))

def write_coils(address,values,slave):  # 写多个线圈
    result = client.write_coils(address=address, values=values, slave=slave)
    if result.isError():
        print("写入错误: %s" % result)
    else:
        print("写入从机%d,地址%d的线圈值: %s" % (slave, address, values))

def write_registers(address,values,slave):  # 写多个寄存器
    result = client.write_registers(address=address, values=values, slave=slave)
    if result.isError():
        print("写入错误: %s" % result)
    else:
        print("写入从机%d,地址%d的保持寄存器: %s" % (slave, address, values))

if __name__ == "__main__":

    # 创建Modbus TCP客户端
    client = ModbusTcpClient(host="200.100.1.2", port=5020)

    # 连接到Modbus TCP从站
    connection = client.connect()
    # r1 = client.read_coils(address=1, count=10, slave=1)
    # print(r1.bits)
    read_coil(address=1, count=9, slave=1)

    write_coil(address=9, value=1, slave=1)

    read_coil(address=1, count=9, slave=1)

    # 关闭连接
    client.close()


