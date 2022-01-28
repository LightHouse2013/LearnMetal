//
//  ViewController.swift
//  Lesson1-DrawTriangle
//
//  Created by zhang.wenhai on 2022/1/27.
//

import UIKit
import Metal
import simd

class ViewController: UIViewController {
    
    let mtlDevice = MTLCreateSystemDefaultDevice()!
    var commandQueue: MTLCommandQueue!
    var mtlLibary: MTLLibrary!
    var pipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var colorBuffer: MTLBuffer!
    
    let mtlLayer = CAMetalLayer()
    var displaylink: CADisplayLink!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDataBuffer()
        setupPipelineState()
        setupDisplaylink()
    }
}

private extension ViewController {
    func render() {
        
        /*
         nextDrawable：一个CAMetalLayer对象维护一个用于显示图层内容的内部纹理池，每个都包装在一个CAMetalDrawable对象中。
         使用此方法从池中检索下一个可用的绘制对象。如果所有的drawables都在使用中，该layer等待1秒，直到一个变为可用，之后返回nil。allowsNextDrawableTimeout属性会影响此行为。
         如果layer的pixelFormat或其他属性无效，此方法返回nil。
         */
        
        /*
         descriptor的loadAction和storeAction属性被执行在rendering pass的起始和结束点。
         LoadAction状态如下：
         - MTLLoadActionClear 给具体的attachment descriptor写相同的像素值，clearColor为填充颜色值；
         - MTLLoadActionLoad 保持已存在的纹理的内容；
         - MTLLoadActionDontCare 在rendering pass的起始点允许每个像素可赋值任何值。

         StoreAction状态如下：
         - MTLStoreActionStore 保存rendering pass的最终结果到附件中，对于颜色附件是默认设置；
         - MTLStoreActionMultisampleResolve 它将渲染目标的多样本数据解析为单个样本值，将它们存储在由附件属性resolveTexture指定的纹理中，并未定义附件的内容，细节可以看
         - MTLStoreActionDontCare rendering pass完成后的附件的未定义状态，对depth and stencil附件是默认值；
         */
        guard let drawable = mtlLayer.nextDrawable() else { return }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1.0)
        
        /*
         MTLRenderCommandEncoder拼接渲染、计算、标脏的指令到command buffer中，command buffer最终提交到运行的设备上
         */
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(colorBuffer, offset: 0, index: 1)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

private extension ViewController {
    func setupUI() {
        self.view.backgroundColor = .white
        
        mtlLayer.device = mtlDevice
        mtlLayer.pixelFormat = .bgra8Unorm
        mtlLayer.framebufferOnly = true
        mtlLayer.frame = CGRect(origin: CGPoint(x: 0, y: 200),
                                size: CGSize(width: self.view.bounds.width,
                                             height: self.view.bounds.width))
        view.layer.addSublayer(mtlLayer)
    }
    
    func setupDisplaylink() {
        self.displaylink = CADisplayLink(target: self, selector: #selector(renderLoop))
        self.displaylink.add(to: .main, forMode: .common)
    }
    
    func setupDataBuffer() {
        // 顶点参数装载到MTLBuffer中，才能上传到Metal Shader里，即上传到GPU里；
        // 前4个位position，后4个为color        
        let vertices: [Float] = [ 0.0,  0.5, 0.0,
                                 -0.5, -0.5, 0.0,
                                  0.5, -0.5, 0.0]
        let vertexDataSize = vertices.count * MemoryLayout.size(ofValue: vertices[0])
        vertexBuffer = mtlDevice.makeBuffer(bytes: vertices, length: vertexDataSize, options: [])
        
        let colors: [Float] = [1.0, 0.0, 0.0, 1.0,
                               0.0, 1.0, 0.0, 1.0,
                               0.0, 0.0, 1.0, 1.0]
        let colorDataSize = colors.count * MemoryLayout.size(ofValue: colors[0])
        colorBuffer = mtlDevice.makeBuffer(bytes: colors, length: colorDataSize, options: [])
    }
    
    func setupPipelineState() {
        // 获取默认的library，main bundle里的shader都会被加载到这里，并获取fragment和vertex函数
        mtlLibary = mtlDevice.makeDefaultLibrary()!
        let fragmentProgram = mtlLibary.makeFunction(name: "basic_fragment")
        let vertexProgram = mtlLibary.makeFunction(name: "basic_vertex")
        
        /*
         创建MTLRenderPipelineState对象，定义渲染管线的状态（shader、blending、多重采样、可视化测试等）；
         MTLRenderPipelineState在Metal框架中渲染管线这个概念的抽象(同OpenGL)，它表示了一次完整的绘制流程，可包括多个DrawCall。
         MTLRenderPipelineState对象是一个长期存在的持久对象，可以在render command encoder之前创建提前缓存，并跨多个render command encoder重用，MTLRenderPipelineState是个不可修改对象。
         */
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try! mtlDevice.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        
        /*
         每个MTLDevice有且只有一个指令队列，它应该只被创建一次；
         是GPU运算队列，每个GPU单元对应一个运算队列，是一系列command buffer的队列，组织command buffer的执行顺序。
         MTLCommandQueue协议主要是定义了创建command buffer对象的接口。线程安全，允许多个激活的command buffer同时被编码
         */
        commandQueue = mtlDevice.makeCommandQueue()!
    }
    
    @objc
    func renderLoop() {
        autoreleasepool {
            render()
        }
    }
}

