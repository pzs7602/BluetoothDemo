//
//  ViewController.swift
//  BluetoothDemo
//
//  Created by panzhansheng on 2018/5/25.
//  Copyright © 2018年 panzhansheng. All rights reserved.
//
/*
 本程序演示蓝牙LE 数据传输
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
 交互过程：
    本程序有2个角色：central/peripheral，通过 UI界面的开关决定，默认为 central
    peripheral 宣告服务，central 扫描到指定peripheral后，连接 peripheral，随后寻找
    服务，找到服务后再寻找服务中的characteristic，找到后保存 characteristic，并向 peripheral 的BLE_GDOUREADWRITE_Characteristic_CBUUID 发出读取请求，peripheral 收到请求后发出数据 "Hello,world"
    central 收到读取数据后向 pheripheral 发出写数据请求，后者收到写数据后显示，central收到写数据成功回应后发出
    第二次读取数据请求，peripheral 收到请求后发出 "writeOK"，central 收到第二次读取数据后显示
*/
import UIKit
import CoreBluetooth

// identified by 128-bit Bluetooth-specific UUID, use uuidgen to generate a UUID string
let BLE_GDOU_Service_CBUUID = CBUUID(string: "16EDCFC5-F8A6-4057-BE49-6B0DB769C15B")
let BLE_GDOUREADWRITE_Characteristic_CBUUID = CBUUID(string: "4924E283-4183-435C-AB62-6C04F831BC83")
let BLE_GDOUREADWRITE_Characteristic_CBUUID2 = CBUUID(string: "599076F9-D935-44FE-BA9B-A390F46D0F1C")
let BLE_GDOUNOTIFY_Characteristic_CBUUID = CBUUID(string: "D1839FB7-AEBC-4D7C-9192-BE71F7483F82")
class ViewController: UIViewController,CBPeripheralManagerDelegate,CBCentralManagerDelegate,CBPeripheralDelegate {

    @IBOutlet weak var myTextBox: UITextView!
    @IBOutlet weak var commandButton: UIButton!
    @IBOutlet weak var isPeripheral: UISwitch!
    var centralManager: CBCentralManager?
    var peripheral: CBPeripheral?
    var peripheralManager: CBPeripheralManager?
    var characteristic: CBCharacteristic?
    var notifyCharacteristic: CBCharacteristic?
    var service: CBMutableService?
    var timer: Timer?
    // mark for readValue operation of central:
    // 0 表示central 连接 peripheral 后的 读取, 1 表示 central 向 peripheral 写数据后读取 peripheral 的返回数据(表明写数据是否正常)
    // 注意：由于读取数据的设置是在 didReceiveRead request 方法，该方法由 peripheral 设备代码执行，故 readValueMark 的设置应该在 peripheral 设备代码中进行
    var readValueMark:Int = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        // the app is act as central role by default
        // this will invoke centralManagerDidUpdateState
        let centralQueue: DispatchQueue = DispatchQueue(label: "com.gdou.centralQueueName", attributes: .concurrent)
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)

    }
    func timerHandler(timer:Timer)
    {
        if let manager = self.peripheralManager,let char = self.notifyCharacteristic{
            // update value for specified characteristic for all centrals
            let value = manager.updateValue(getNowFormattedDate()!, for: char as! CBMutableCharacteristic, onSubscribedCentrals: nil)
//            print("send updated value to central for result:\(value)")
        }

    }
    func getNowFormattedDate() -> Data?
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeString = dateFormatter.string(from: NSDate() as Date)
        print("timer fired:\(timeString)")
        let data = timeString.data(using: String.Encoding.utf8)
        return data
    }
    // if in central role, send a command string to periperal device
    // and will invoke didReceiveWrite requests:
    @IBAction func sendCommandButtonAction(_ sender: Any) {
        guard !isPeripheral.isOn else {
            print("only active when peripheral on")
            return
        }
        let data = "DataWritten to peripheral".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
        self.peripheral?.writeValue(data, for: self.characteristic!, type: CBCharacteristicWriteType.withResponse)
    }
    // if peripheral switch is on, then change to act as peripheral role
    @IBAction func isPeripheralSwitchValueChanged(_ sender: Any) {
        if isPeripheral.isOn{
            let peripheralQueue: DispatchQueue = DispatchQueue(label: "com.gdou.peripheralQueueName", attributes: .concurrent)
            // this will invoke peripheralManagerDidUpdateState
            self.peripheralManager = CBPeripheralManager(delegate: self, queue: peripheralQueue)
            self.centralManager = nil
            if self.timer == nil{
                self.timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: timerHandler)
            }
            self.commandButton.isEnabled = false
        }
        // if peripheral switch is off, change to central role
        else{
            self.peripheralManager = nil
            self.timer?.invalidate()
            self.timer = nil
            let centralQueue: DispatchQueue = DispatchQueue(label: "com.gdou.centralQueueName", attributes: .concurrent)
            centralManager = CBCentralManager(delegate: self, queue: centralQueue)
            self.commandButton.isEnabled = true
        }
    }
    // Invoked when the central manager’s state is updated
    // the device's Bluetooth state; we can ONLY
    // scan for peripherals if Bluetooth is .poweredOn
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
            
        case .unknown:
            print("Bluetooth central status is UNKNOWN")
        case .resetting:
            print("Bluetooth central status is RESETTING")
        case .unsupported:
            print("Bluetooth central status is UNSUPPORTED")
        case .unauthorized:
            print("Bluetooth central status is UNAUTHORIZED")
        case .poweredOff:
            print("Bluetooth central status is POWERED OFF")
        case .poweredOn:
            print("Bluetooth central status is POWERED ON")
            
            DispatchQueue.main.async { () -> Void in
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
            
            // scan for peripherals that we're interested in
            // or nil for all peripherals
            centralManager?.scanForPeripherals(withServices: [BLE_GDOU_Service_CBUUID])
            
        } // END switch
        
    } // END func centralManagerDidUpdateState
    // MARK: CBCentralManagerDelegate methods
    // Invoked when the central manager discovers a peripheral while scanning
    // RSSI The current received signal strength indicator (RSSI) of the peripheral, in decibels(负数，值越小越远)
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        // set remote peripheral delegate
        self.peripheral?.delegate = self
        self.centralManager?.stopScan()
        self.centralManager?.connect(self.peripheral!)
        // peripheral name is the string you see in bluetooth
        print("peripheral name:\(String(describing: peripheral.name)) ,RSSI=\(RSSI)")
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        DispatchQueue.main.async { () -> Void in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            self.myTextBox.text = (self.myTextBox.text == nil ? "" : self.myTextBox.text!) + "connected to:" + (peripheral.name == nil ? "nil" : peripheral.name!)
        }
        
        // STEP 8: look for services of interest on peripheral
        self.peripheral?.discoverServices([BLE_GDOU_Service_CBUUID])
        
    } // END func centralManager(... didConnect peripheral

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { () -> Void in
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
        // scan for service again
        centralManager?.scanForPeripherals(withServices: [BLE_GDOU_Service_CBUUID])
        print("didDisconnectPeripheral")
        DispatchQueue.main.async {
            self.myTextBox.text = "didDisconnectPeripheral:" + (error?.localizedDescription)!
        }
    }
    // MARK: CBPeripheralDelegate methods
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        for service in peripheral.services! {
            
            if service.uuid == BLE_GDOU_Service_CBUUID {
                
                print("Service: \(service)")
                DispatchQueue.main.async {
                    self.myTextBox.text = self.myTextBox.text! + "\nfound service:" + service.description
                }

                // STEP 9: look for characteristics of interest
                // within services of interest
                // An array of CBUUID objects—representing characteristic UUIDs—can be provided in the characteristicUUIDs parameter. As a result, the peripheral returns only the characteristics of the service that your app is interested in (recommended). If the characteristicUUIDs parameter is nil, all the characteristics of the service are returned; setting the parameter to nil is considerably slower and is not recommended
                // discover all characteristics
                peripheral.discoverCharacteristics(nil, for: service)
                
            }
            
        }
        
    } // END func peripheral(... didDiscoverServices
    // invoke by central
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        for characteristic in service.characteristics! {
//            print(characteristic)
            if characteristic.uuid == BLE_GDOUREADWRITE_Characteristic_CBUUID {
                // send read request to peripheral
                peripheral.readValue(for: characteristic)
                self.characteristic = characteristic
                print("readValueMark set to 0")

            }
            else if characteristic.uuid == BLE_GDOUNOTIFY_Characteristic_CBUUID{
                self.notifyCharacteristic = characteristic
                self.peripheral?.setNotifyValue(true, for: self.notifyCharacteristic!)
                print("didDiscoverCharacteristicsFor write")
            }
        } // END for
        
    } // END func peripheral(... didDiscoverCharacteristicsFor service
    // This method is invoked when your app calls the readValue(for:) method, or when the peripheral notifies your app that the value of the characteristic for which notifications and indications are enabled (via a successful call to setNotifyValue(_:for:)) has changed
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("error didUpdateValueFor.\(String(describing: error?.localizedDescription))")
            return
        }
        if characteristic.uuid == BLE_GDOUREADWRITE_Characteristic_CBUUID {
            let data = characteristic.value
            let str = String(data:data!, encoding: String.Encoding.utf8)!
            print("char value=\(String(describing: str))")
            DispatchQueue.main.async {
                self.myTextBox.text = self.myTextBox.text! + "\nreadValue from READWRITE:" + str
            }
        }
        else if characteristic.uuid == BLE_GDOUNOTIFY_Characteristic_CBUUID {
            let data = characteristic.value
            let str = String(data:data!, encoding: String.Encoding.utf8)!
            print("char value=\(String(describing: str))")
            DispatchQueue.main.async {
                self.myTextBox.text = self.myTextBox.text! + "\nreadValue from NOTIFY:" + str
            }
        } // END if characteristic.uuid ==...

    } // END func peripheral(... didUpdateValueFor characteristic
    // will invoked by central device
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("error didWriteValueFor.\(String(describing: error?.localizedDescription))")
            return
        }
        // at this time charateristic.value is nil
//        let dataString = String(data:characteristic.value!, encoding: String.Encoding.utf8)
        print("didWriteValueFor: \(String(describing: characteristic.uuid.uuidString)),value:\(String(describing: characteristic.value))")
        if characteristic.uuid == BLE_GDOUREADWRITE_Characteristic_CBUUID {
            //
            peripheral.readValue(for: self.characteristic!)
        }
    }
    // invoked by peripheral when characteristic value changed
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            print("error didUpdateValueFor.\(String(describing: error?.localizedDescription))")
            return
        }
        
    }
    
    // invoke when CBPeripheralManager' state changed
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
            
            case .unknown:
                print("Bluetooth peripheral status is UNKNOWN")
            case .resetting:
                print("Bluetooth peripheral status is RESETTING")
            case .unsupported:
                print("Bluetooth peripheral status is UNSUPPORTED")
            case .unauthorized:
                print("Bluetooth peripheral status is UNAUTHORIZED")
            case .poweredOff:
                print("Bluetooth peripheral status is POWERED OFF")
            case .poweredOn:
                print("Bluetooth peripheral status is POWERED ON")
            
                DispatchQueue.main.async { () -> Void in
                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
                }
                
                // this characteristic is for read data from peripheral device
                // nil value means we will set this later
                self.characteristic = CBMutableCharacteristic(type: BLE_GDOUREADWRITE_Characteristic_CBUUID,properties: CBCharacteristicProperties(rawValue: CBCharacteristicProperties.RawValue(UInt8(CBCharacteristicProperties.read.rawValue) | UInt8(CBCharacteristicProperties.write.rawValue))),value: nil,permissions: CBAttributePermissions(rawValue: CBAttributePermissions.RawValue(UInt8(CBAttributePermissions.readable.rawValue) | UInt8(CBAttributePermissions.writeable.rawValue))))
                // this characteristic is for notify peripheral device
                self.notifyCharacteristic = CBMutableCharacteristic(type: BLE_GDOUNOTIFY_Characteristic_CBUUID,properties: CBCharacteristicProperties.notify,value: nil,permissions: CBAttributePermissions.readable)

                self.service = CBMutableService(type: BLE_GDOU_Service_CBUUID, primary: true)
                // service includes 2 characteristics
                self.service?.characteristics = [self.characteristic,self.notifyCharacteristic] as? [CBCharacteristic]
                // add 2 characteristics to service
                self.peripheralManager?.add(self.service!)
            
        } // END switch
    }
    // MARK: CBPeripheralManagerDelegate methods
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if error != nil{
            print("Error add service:\(String(describing: error?.localizedDescription))")
        }
        else{
            print("peripheral service added")
            self.peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [BLE_GDOU_Service_CBUUID]])
        }
    }
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if error != nil{
            print("Error peripheralManagerDidStartAdvertising:\(String(describing: error?.localizedDescription))")
        }
        else{
            print("peripheralManagerDidStartAdvertising ok")
        }
    }
    // invoked by peripheral when central subscribe notification for characteristic
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil{
            print("Error didUpdateNotificationStateFor::\(String(describing: error?.localizedDescription))")
        }
        else{
            print("didUpdateNotificationStateFor:\(characteristic.uuid)")
        }
        
    }
    // Invoked when a local peripheral device receives an Attribute Protocol (ATT) read request for a characteristic that has a dynamic value.
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == BLE_GDOUREADWRITE_Characteristic_CBUUID{
            // set characteristic value
            var data:Data? = nil
            if self.readValueMark == 0{
                data = "Hello,world".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
                request.value = data
                print("readValueMark=\(self.readValueMark)")
            }
            else if self.readValueMark == 1{
                data = "writeOK".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
                request.value = data!

            }
            // respond to the remote central to indicate that the request was successfully fulfilled. Do so by calling the respondToRequest:withResult: method of the CBPeripheralManager class, passing back the request (whose value you updated) and the result of the request
            self.peripheralManager?.respond(to: request, withResult: CBATTError.success)
            print("characteristic value:\(String(describing: String(data:request.value!, encoding: String.Encoding.utf8)!))")
        }
        else if request.characteristic.uuid == BLE_GDOUNOTIFY_Characteristic_CBUUID{
            self.peripheralManager?.respond(to: request, withResult: CBATTError.success)
            DispatchQueue.main.async {
                self.myTextBox.text = "write:" + String(data:request.value!, encoding: String.Encoding.utf8)!
            }
        }
    }
    // will invoked by peripheral
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest])
    {
        for request in requests {
            print("request chat:\(request.characteristic), value=\(String(describing: request.characteristic.value))")
            if request.characteristic.uuid == BLE_GDOUREADWRITE_Characteristic_CBUUID && request.characteristic.properties.contains(CBCharacteristicProperties.write){
                // respond to the remote central to indicate that the request was successfully fulfilled. Do so by calling the respondToRequest:withResult: method of the CBPeripheralManager class, passing back the request (whose value you updated) and the result of the request
                // set this mark for the second time readValue
                self.readValueMark = 1
                self.peripheralManager?.respond(to: request, withResult: CBATTError.success)
                print("characteristic value:\(String(describing: String(data:request.value!, encoding: String.Encoding.utf8)!))")
                DispatchQueue.main.async {
                    self.myTextBox.text = self.myTextBox.text==nil ? "" : self.myTextBox.text! + "\ncentral write:" + String(data:request.value!, encoding: String.Encoding.utf8)!
                }
            }

        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("central didSubscribeTo characteristic:\(characteristic.uuid)")
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

