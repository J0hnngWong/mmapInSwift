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
            print("outDataPtr : \(String(describing: dataPtr))")
            print("dataLength : \(String(describing: dataLength))")
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
        //用来储存错误
        var outError: Int32
        
        //初始化读取文件内容的指针和长度和错误类型
        outDataPtr = nil
        outDataLength = 0
        outError = 0
        
        //openFile 打开文件
        //O_RDWR 是读取文件用来读写，还有其他参数
        //最后一位是用来标识用户组权限
        //返回值0为打开成功，若权限检查失败等失败会返回-1 其他错误会返回响应错误代码
        //参数参照 http://c.biancheng.net/cpp/html/238.html
        fileDescriptor = open(inPathName, O_RDWR, 0)
        
        if fileDescriptor < 0 {
            //打开文件错误放入outError里面
            outError = errno
            return false
        }
        
        //now we know the file exist, so we can retrieve the data
        //fstat()用来将参数fileDescriptor 所指的文件状态, 复制到参数statInfo 所指的结构中(struct stat). Fstat()与stat()作用完全相同, 不同处在于传入的参数为已打开的文件描述词. 详细内容请参考stat(). 具体参照：https://blog.csdn.net/allenguo123/article/details/41011801
        //成功返回0不成功返回-1
        if fstat(fileDescriptor, &statInfo) != 0 {
            //赋值文件属性错误，错误信息存入outError里面
            outError = errno
            return false
        } else {
            //ftruncate()会将参数fileDescriptor 指定的文件大小改为参数statInfo.st_size+4 指定的大小。参数fileDescriptor 为已打开的文件描述词，而且必须是以写入模式打开的文件。如果原来的文件大小比参数statInfo.st_size+4大，则超过的部分会被删去。
            //参考：https://www.jb51.net/article/71789.htm
            ftruncate(fileDescriptor, statInfo.st_size+4)
            //mmap中具体的制定操作系统去执行的写操作 fsync()负责将参数fileDescriptor 所指的文件数据, 由系统缓冲区写回磁盘, 以确保数据同步.
            fsync(fileDescriptor)
            //参考：http://c.biancheng.net/cpp/html/138.html
            //参数说明：
            /* 参数    说明
            start    指向欲对应的内存起始地址，通常设为NULL，代表让系统自动选定地址，对应成功后该地址会返回。
             
            length    代表将文件中多大的部分对应到内存。
             
            prot     代表映射区域的保护方式，有下列组合：
                PROT_EXEC  映射区域可被执行；
                PROT_READ  映射区域可被读取；
                PROT_WRITE  映射区域可被写入；
                PROT_NONE  映射区域不能存取。
             
            flags    会影响映射区域的各种特性：
                MAP_FIXED  如果参数 start 所指的地址无法成功建立映射时，则放弃映射，不对地址做修正。通常不鼓励用此旗标。
                MAP_SHARED  对应射区域的写入数据会复制回文件内，而且允许其他映射该文件的进程共享。
                MAP_PRIVATE  对应射区域的写入操作会产生一个映射文件的复制，即私人的"写入时复制" (copy on write)对此区域作的任何修改都不会写回原来的文件内容。
                MAP_ANONYMOUS  建立匿名映射，此时会忽略参数fd，不涉及文件，而且映射区域无法和其他进程共享。
                MAP_DENYWRITE  只允许对应射区域的写入操作，其他对文件直接写入的操作将会被拒绝。
                MAP_LOCKED  将映射区域锁定住，这表示该区域不会被置换(swap)。
            
                在调用mmap()时必须要指定MAP_SHARED 或MAP_PRIVATE。
             
            fd    open()返回的文件描述词，代表欲映射到内存的文件。
             
            offset    文件映射的偏移量，通常设置为0，代表从文件最前方开始对应，offset必须是分页大小的整数倍。
             
             返回值：若映射成功则返回映射区的内存起始地址，否则返回MAP_FAILED(-1)，错误原因存于errno 中。
             
             错误代码：
             EBADF  参数fd 不是有效的文件描述词。
             EACCES  存取权限有误。如果是MAP_PRIVATE 情况下文件必须可读，使用MAP_SHARED 则要有PROT_WRITE 以及该文件要能写入。
             EINVAL  参数start、length 或offset 有一个不合法。
             EAGAIN  文件被锁住，或是有太多内存被锁住。
             ENOMEM  内存不足。
            */
            outDataPtr = mmap(nil, Int(statInfo.st_size+4), PROT_READ|PROT_WRITE, MAP_FILE|MAP_SHARED, fileDescriptor, 0)
            if outDataPtr == MAP_FAILED {
                //映射错误失败错误类型存入outError里面
                outError = errno
                return false
            } else {
                outDataLength = size_t(statInfo.st_size)
            }
        }
        
        close(fileDescriptor)
        
        return true
    }

}

