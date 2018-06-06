# BluetoothDemo本程序演示蓝牙LE 数据传输
 本程序可作为2个蓝牙角色：central 及 peripheral。由UI 界面 as peripheral 开关决定
 程序交互过程：
 central                  peripheral
 扫描 peripheral        准备Service 及 Characteristic
 已添加服务
 广播服务
 发现 peripheral
 连接 peripheral -->
 已连接
 寻找服务
 发现服务
 寻找characteristic
 发现characteristic
 已发现
 读/写数据请求            回应读/写数据请求
 读写数据  <-read----write->
 Interact procedure：
 
 This App has two roles: central/peripheral which determined by UISwitch in UI, the default is central
 peripheral advertise its service，central connect to the peripheral when scaned the specified peripheral.After connection, 
 the central try to find the specified service and then the specified characteristic and keep the characteristic if found one.
 Then the central sends a read request for BLE_GDOUREADWRITE_Characteristic_CBUUID, the peripheral then sends data "Hello,world" 
 when it received the read request. The central then sends a write request to peripheral when it receives the read data. 
 The peripheral display the write data, central receives the response of success of write data and send the read request for sencond time.
 The peripheral receives this request and send data "WriteOK", central display this data when received.
# Environment
Xcode 9.0+/Swift 4.1
