//
//  mmapRWTest.swift
//  mmapDemo
//
//  Created by 王嘉宁 on 2019/4/19.
//  Copyright © 2019 Johnny. All rights reserved.
//

import Foundation

class mmapRWTest: NSObject {
    
    override init() {
        super.init()
        //创建文件
        //获取文件路径
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        //要写入的文件路径加文件名称
        let filePath = "\(path ?? "")/textData.txt"
        let fileManager = FileManager.init()
        let exist = fileManager.fileExists(atPath: filePath)
        if !exist {
            let createResult = fileManager.createFile(atPath: filePath, contents: nil, attributes: nil)
        }
    }
    
    public func fileMapping() {
        //获取文件路径
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        //要写入的文件路径加文件名称
        let filePath = "\(path ?? "")/textData.txt"
        print("filePath : \(filePath)")
        
        //储存文件长度变量
        var dataLength: size_t?
        //文件起始指针
        var dataPtr: UnsafeMutableRawPointer?
        //储存读取内存数据起始位置的指针
        var start: UnsafeMutableRawPointer?
        
        //用来储存文件数据？
        var fileDescriptor: Int32
        //用来储存文件属性？
        var statInfo = stat()
        //用来储存错误
        var outError: Int32
        
        //初始化读取文件内容的指针和长度和错误类型
        dataPtr = nil
        dataLength = 0
        outError = 0
        
        fileDescriptor = open(filePath, O_RDWR, 0)
        
        if fileDescriptor < 0 {
            //打开文件错误放入outError里面
            outError = errno
        }
        
        if fstat(fileDescriptor, &statInfo) != 0 {
            outError = errno
        } else {
            //修改文件大小
            ftruncate(fileDescriptor, statInfo.st_size + 4)
            //定义同步写入操作
            fsync(fileDescriptor)
            dataPtr = mmap(nil, Int(statInfo.st_size + 4), PROT_READ|PROT_WRITE, MAP_FILE|MAP_SHARED, fileDescriptor, 0)
            if dataPtr == MAP_FAILED {
                outError = errno
            } else {
                dataLength = size_t(statInfo.st_size)
            }
        }
        close(fileDescriptor)
        
        
        //写入的操作
        memcpy(dataPtr, "CCCC", 4)
        //释放内存时映射区域的大小
        munmap(dataPtr, 4)
    }
}
