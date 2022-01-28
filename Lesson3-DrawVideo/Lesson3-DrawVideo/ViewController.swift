//
//  ViewController.swift
//  Lesson3-DrawVideo
//
//  Created by zhang.wenhai on 2022/1/27.
//

import UIKit
import Metal
import simd
import AVFoundation

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
    
    var videoFrameReader: VideoFrameReader!
    var asset: AVAsset!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupVideoFrameReader()
        setupVertexBuffer()
        setupTexture()
        setupPipelineState()
        setupDisplaylink()
        videoFrameReader.play()
    }
}

private extension ViewController {
    func render(pixelBuffer: CVPixelBuffer) {
        fullFillTexture(pixelBuffer: pixelBuffer)
        
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
        displaylink = CADisplayLink(target: self, selector: #selector(renderLoop(link:)))
        displaylink.preferredFramesPerSecond = 30
        displaylink.add(to: .main, forMode: .common)
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
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { fatalError() }
        let width = Int(videoTrack.naturalSize.width)
        let height = Int(videoTrack.naturalSize.height)

        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.pixelFormat = .bgra8Unorm
        textureDescriptor.width = width
        textureDescriptor.height = height
        self.texture = mtlDevice.makeTexture(descriptor: textureDescriptor)
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
    
    func setupVideoFrameReader() {
        let assetUrl = Bundle.main.url(forResource: "3D-FLY", withExtension: "MOV")!
        asset = AVAsset(url: assetUrl)
        videoFrameReader = VideoFrameReader(asset: asset)
    }
    
    @objc
    func renderLoop(link: CADisplayLink) {
        let timeStamp = link.timestamp
        autoreleasepool {
            if let pixelBuffer = self.videoFrameReader.getFrame(at: timeStamp) {
                render(pixelBuffer: pixelBuffer)
            } else {
                print("Missing Frame...")
            }
        }
    }
}

private extension ViewController {
    func fullFillTexture(pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let region = MTLRegion(origin: MTLOriginMake(0, 0, 0), size: MTLSizeMake(width, height, 1))
        
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            self.texture.replace(region: region, mipmapLevel: 0, withBytes: baseAddress, bytesPerRow: bytesPerRow)
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
}
