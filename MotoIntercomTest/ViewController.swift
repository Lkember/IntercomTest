//
//  ViewController.swift
//  MotoIntercomTest
//
//  Created by Logan Kember on 2017-03-20.
//  Copyright © 2017 Logan Kember. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    //Thread
    var recordingQueue = DispatchQueue(label: "recordingQueue", qos: DispatchQoS.userInteractive)
    var localPlayerQueue = DispatchQueue(label: "localPlayerQueue", qos: DispatchQoS.userInteractive)
    var receivingQueue = DispatchQueue(label: "receivingQueue", qos: DispatchQoS.userInteractive)
    var audioPlayerQueue = DispatchQueue(label: "audioPlayerQueue", qos: DispatchQoS.userInteractive)
    
    // Audio Capture and Playing
    var localAudioEngine: AVAudioEngine = AVAudioEngine()
    var localAudioPlayer: AVAudioPlayerNode = AVAudioPlayerNode()
    var localInput: AVAudioInputNode?
    var localInputFormat: AVAudioFormat?
    
//    var peerAudioEngine: AVAudioEngine = AVAudioEngine()
//    var peerAudioPlayer: AVAudioPlayerNode = AVAudioPlayerNode()
//    var peerInput: AVAudioInputNode?
//    var peerInputFormat: AVAudioFormat?
    
    
    @IBOutlet weak var startButton: UIButton!
    
    
    override func viewDidLoad() {
        print("\(#file) > \(#function) > Entry")
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        print("\(#file) > \(#function) > Exit")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func startButtonIsTouched(_ sender: Any) {
        
        print("\(#file) > \(#function) > Entry")
        recordingQueue.sync {
            setupAVRecorder()
            startRecordingAndPlayback()
        }
        print("\(#file) > \(#function) > Exit")
    }
    
    
    func setupAVRecorder() {
        
        print("\(#file) > \(#function) > Entry")
        
        // Setting up audio engine for local recording and sounds
        self.localInput = self.localAudioEngine.inputNode
        self.localAudioEngine.attach(self.localAudioPlayer)
        self.localInputFormat = self.localInput?.inputFormat(forBus: 1)
        self.localAudioEngine.connect(self.localAudioPlayer, to: self.localAudioEngine.mainMixerNode, format: self.localInputFormat)
        
        print("\(#file) > \(#function) > localInputFormat = \(self.localInputFormat.debugDescription)")
        
//        self.audioPlayerQueue.async {
//            self.peerInput = self.peerAudioEngine.inputNode
//            self.peerAudioEngine.attach(self.peerAudioPlayer)
//            self.peerInputFormat = self.peerInput?.inputFormat(forBus: 1)
//            self.peerAudioEngine.connect(self.peerAudioPlayer, to: self.peerAudioEngine.mainMixerNode, format: self.peerInputFormat)
//            
//            print("\(#file) > \(#function) > peerInputFormat = \(self.peerInputFormat.debugDescription)")
//        }
        print("\(#file) > \(#function) > Exit")
    }
    
    
    func startRecordingAndPlayback() {
        print("\(#file) > \(#function) > Entry")
        
        localInput?.installTap(onBus: 1, bufferSize: 2048, format: localInputFormat) {
            (buffer, time) -> Void in
            
            // the audio being sent will be played locally as well
            self.localPlayerQueue.async {
                self.localAudioPlayer.scheduleBuffer(buffer)
            }
            
            let data = self.audioBufferToData(audioBuffer: buffer)
            
            let audioBuffer = self.dataToAudioBuffer(data: data)
            print("\(#file) > \(#function) > audioBuffer channel count: \(audioBuffer.format.channelCount)")
            print("\(#file) > \(#function) > localInput format channel count: \(self.localInputFormat?.channelCount)")
            
            self.audioPlayerQueue.async {
                self.localAudioPlayer.scheduleBuffer(audioBuffer)
                if (!self.localAudioPlayer.isPlaying && self.localAudioEngine.isRunning) {
                    self.localAudioPlayer.play()
                }
            }
        }
        
        localPlayerQueue.sync {
            do {
                try self.localAudioEngine.start()
            }
            catch let error as NSError {
                print("\(#file) > \(#function) > Error starting audio engine: \(error.localizedDescription)")
            }
            
            self.localAudioPlayer.play()
            print("\(#file) > \(#function) > Audio is playing...")
        }
        
        print("\(#file) > \(#function) > Exit")
    }
    
    
    // Converts an audio buffer to Data
    func audioBufferToData(audioBuffer: AVAudioPCMBuffer) -> Data {
        
        print("\(#file) > \(#function) > Entry")
        
        let channelCount = 1
        let bufferLength = (audioBuffer.frameCapacity * audioBuffer.format.streamDescription.pointee.mBytesPerFrame)
        
        let channels = UnsafeBufferPointer(start: audioBuffer.floatChannelData, count: Int(bufferLength))
        let data = Data(bytes: channels[0], count: Int(bufferLength))
        
        print("\(#file) > \(#function) > Exit bufferLength \(bufferLength)")
        return data
    }
    
    // Converts Data to an audio buffer
    func dataToAudioBuffer(data: Data) -> AVAudioPCMBuffer {
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 1, interleaved: false)
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: UInt32(data.count)/2)
        audioBuffer.frameLength = audioBuffer.frameCapacity
        for i in 0..<data.count/2 {
            // transform two bytes into a float (-1.0 - 1.0), required by the audio buffer
            audioBuffer.floatChannelData?.pointee[i] = Float(Int16(data[i*2+1]) << 8 | Int16(data[i*2]))/Float(INT16_MAX)
        }
        
        return audioBuffer
    }
    
}

