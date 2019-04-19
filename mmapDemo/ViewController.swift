//
//  ViewController.swift
//  mmapDemo
//
//  Created by 王嘉宁 on 2019/4/8.
//  Copyright © 2019 Johnny. All rights reserved.
//

import Foundation
import Darwin
import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        //获取文件路径
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        //要写入的内容
        let str = "AAA"
        //要写入的文件路径加文件名称
        let filePath = "\(path ?? "")/text.txt"
        //打印文件路径加名称
        print("filePath is : \(filePath)")
        //传统write写法
        try? str.write(toFile: filePath, atomically: true, encoding: .utf8)
        //使用mmap处理文件
        processFile(inPathName: filePath)
        //取出处理之后的文件
        let result = try? String(contentsOfFile: filePath, encoding: .utf8)
        //打印文件内容
        print(result)
    }

    func processFile(inPathName: String) {
        //储存文件长度变量
        var dataLength: size_t?
        //
        var dataPtr: UnsafeMutableRawPointer?
        //储存读取内存数据起始位置的指针
        var start: UnsafeMutableRawPointer?
        //使用函数读取内存
        if mapFile(inPathName: inPathName, outDataPtr: &dataPtr, outDataLength: &dataLength) {
            start = dataPtr
            dataPtr = dataPtr! + 3
            memcpy(dataPtr, "CCCC", 4)
            munmap(start, 7)
        }
    }
    
    /// 输入文件名称（包括路径）读取完成之后储存指针的变量 读取完成之后储存读取的数据长度,来返回一个布尔值表明是否访问成功
    /// - Parameters:
    ///   - inPathName: 文件路径包含名称
    ///   - outDataPtr: 读取完成之后储存指针的变量
    ///   - outDataLength: 读取完成之后储存读取的数据长度
    /// - Returns: 是否访问成功
    func mapFile(inPathName: String, outDataPtr: inout UnsafeMutableRawPointer?, outDataLength: inout size_t?) -> Bool {
        //用来储存文件数据？
        var fileDescriptor: Int32
        //用来储存文件属性？
        var statInfo = stat()
        
        //初始化读取文件内容的指针和长度
        outDataPtr = nil
        outDataLength = 0
        
        //openFile 打开文件
        //O_RDWR 是读取文件用来读写，还有其他参数
        //最后一位是用来标识用户组权限
        //返回值0为打开成功，若权限检查失败等失败会返回-1 其他错误会返回响应错误代码
        //参数参照 http://c.biancheng.net/cpp/html/238.html
        fileDescriptor = open(inPathName, O_RDWR, 0)
        
        if fileDescriptor < 0 {
            return false
        }
        
        //now we know the file exist, so we can retrieve the data
        //fstat()用来将参数fileDescriptor 所指的文件状态, 复制到参数statInfo 所指的结构中(struct stat). Fstat()与stat()作用完全相同, 不同处在于传入的参数为已打开的文件描述词. 详细内容请参考stat(). 具体参照：https://blog.csdn.net/allenguo123/article/details/41011801
        //成功返回0不成功返回-1
        if fstat(fileDescriptor, &statInfo) != 0 {
            return false
        } else {
            ftruncate(fileDescriptor, statInfo.st_size+4)
            fsync(fileDescriptor)
            outDataPtr = mmap(nil, Int(statInfo.st_size+4), PROT_READ|PROT_WRITE, MAP_FILE|MAP_SHARED, fileDescriptor, 0)
            if outDataPtr == MAP_FAILED {
                return false
            } else {
                outDataLength = size_t(statInfo.st_size)
            }
        }
        
        close(fileDescriptor)
        
        return true
    }

}

