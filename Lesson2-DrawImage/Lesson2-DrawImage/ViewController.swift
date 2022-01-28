//
//  ViewController.swift
//  Lesson2-DrawImage
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
    var textureCoordinatesBuffer: MTLBuffer!
    var numberOfVertices: Int = 0
    var texture: MTLTexture!
    
    let mtlLayer = CAMetalLayer()
    var displaylink: CADisplayLink!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupVertexBuffer()
        setupTexture()
        setupPipelineState()
        setupDisplaylink()
    }
}

private extension ViewController {
    func render() {
        guard let drawable = mtlLayer.nextDrawable() else { return }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1.0)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(textureCoordinatesBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: numberOfVertices)
                
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
    
    func setupVertexBuffer() {
        let vertices: [Float] = [
            /*
             1***2
             ***
             **
             3
                 4
                **
               ***
             6***5
             */
            -0.8,  0.8, 0.0,
             0.8,  0.8, 0.0,
            -0.8, -0.8, 0.0,
                                  
             0.8,  0.8, 0.0,
             0.8, -0.8, 0.0,
            -0.8, -0.8, 0.0]
        let vertexDataSize = vertices.count * MemoryLayout.size(ofValue: vertices[0])
        vertexBuffer = mtlDevice.makeBuffer(bytes: vertices, length: vertexDataSize, options: [])
        numberOfVertices = vertices.count / 3
        
        let textureVertices: [Float] = [
            0.0, 0.0,
            1.0, 0.0,
            0.0, 1.0,
            
            1.0, 0.0,
            1.0, 1.0,
            0.0, 1.0
        ]
        let textureVerticesDataSize = textureVertices.count * MemoryLayout.size(ofValue: vertices[0])
        textureCoordinatesBuffer = mtlDevice.makeBuffer(bytes: textureVertices, length: textureVerticesDataSize, options: [])
    }
    
    func setupTexture() {
        let imagePath = Bundle.main.path(forResource: "light-house", ofType: "jpeg")!
        let image = UIImage(contentsOfFile: imagePath)!
        let imageWidth = Int(image.size.width)
        let imageHeight = Int(image.size.height)

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .rgba8Unorm
        textureDescriptor.width = imageWidth
        textureDescriptor.height = imageHeight
        self.texture = mtlDevice.makeTexture(descriptor: textureDescriptor)
        
        let region = MTLRegion(origin: MTLOriginMake(0, 0, 0), size: MTLSizeMake(imageWidth, imageHeight, 1))
        let bytes = image.getBytes()
        self.texture.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: 4 * imageWidth)
        bytes.deallocate()
    }
    
    func setupPipelineState() {
        mtlLibary = mtlDevice.makeDefaultLibrary()!
        let fragmentProgram = mtlLibary.makeFunction(name: "basic_fragment")
        let vertexProgram = mtlLibary.makeFunction(name: "basic_vertex")
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try! mtlDevice.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        
        commandQueue = mtlDevice.makeCommandQueue()!
    }
    
    @objc
    func renderLoop() {
        autoreleasepool {
            render()
        }
    }
}


private extension UIImage {
    func getBytes() -> UnsafeMutableRawPointer {
        let cgImage = self.cgImage!
        let iwidth = cgImage.width
        let iheight = cgImage.height
        let byteCount = iwidth * iheight * 4
        let bytesPerRow = iwidth * 4
        let colorSpace = cgImage.colorSpace!
        
        let data = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 32)
        
        let context = CGContext(data: data,
                                width: iwidth,
                                height: iheight,
                                bitsPerComponent: 8,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: iwidth, height: iheight))
        return data
    }
}
