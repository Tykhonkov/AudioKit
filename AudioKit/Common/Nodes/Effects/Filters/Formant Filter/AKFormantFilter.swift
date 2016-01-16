//
//  AKFormantFilter.swift
//  AudioKit
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright (c) 2016 Aurelius Prochazka. All rights reserved.
//

import AVFoundation

/// When fed with a pulse train, it will generate a series of overlapping
/// grains. Overlapping will occur when 1/freq < dec, but there is no upper
/// limit on the number of overlaps.
///
/// - parameter input: Input node to process
/// - parameter centerFrequency: Center frequency.
/// - parameter attackDuration: Impulse response attack time (in seconds).
/// - parameter decayDuration: Impulse reponse decay time (in seconds)
///
public class AKFormantFilter: AKNode, AKToggleable {

    // MARK: - Properties


    internal var internalAU: AKFormantFilterAudioUnit?
    internal var token: AUParameterObserverToken?

    private var centerFrequencyParameter: AUParameter?
    private var attackDurationParameter: AUParameter?
    private var decayDurationParameter: AUParameter?

    /// Center frequency.
    public var centerFrequency: Double = 1000 {
        willSet(newValue) {
            if centerFrequency != newValue {
                centerFrequencyParameter?.setValue(Float(newValue), originator: token!)
            }
        }
    }
    /// Impulse response attack time (in seconds).
    public var attackDuration: Double = 0.007 {
        willSet(newValue) {
            if attackDuration != newValue {
                attackDurationParameter?.setValue(Float(newValue), originator: token!)
            }
        }
    }
    /// Impulse reponse decay time (in seconds)
    public var decayDuration: Double = 0.04 {
        willSet(newValue) {
            if decayDuration != newValue {
                decayDurationParameter?.setValue(Float(newValue), originator: token!)
            }
        }
    }

    /// Tells whether the node is processing (ie. started, playing, or active)
    public var isStarted: Bool {
        return internalAU!.isPlaying()
    }

    // MARK: - Initialization

    /// Initialize this filter node
    ///
    /// - parameter input: Input node to process
    /// - parameter centerFrequency: Center frequency.
    /// - parameter attackDuration: Impulse response attack time (in seconds).
    /// - parameter decayDuration: Impulse reponse decay time (in seconds)
    ///
    public init(
        _ input: AKNode,
        centerFrequency: Double = 1000,
        attackDuration: Double = 0.007,
        decayDuration: Double = 0.04) {

        self.centerFrequency = centerFrequency
        self.attackDuration = attackDuration
        self.decayDuration = decayDuration

        var description = AudioComponentDescription()
        description.componentType         = kAudioUnitType_Effect
        description.componentSubType      = 0x666f6669 /*'fofi'*/
        description.componentManufacturer = 0x41754b74 /*'AuKt'*/
        description.componentFlags        = 0
        description.componentFlagsMask    = 0

        AUAudioUnit.registerSubclass(
            AKFormantFilterAudioUnit.self,
            asComponentDescription: description,
            name: "Local AKFormantFilter",
            version: UInt32.max)

        super.init()
        AVAudioUnit.instantiateWithComponentDescription(description, options: []) {
            avAudioUnit, error in

            guard let avAudioUnitEffect = avAudioUnit else { return }

            self.avAudioNode = avAudioUnitEffect
            self.internalAU = avAudioUnitEffect.AUAudioUnit as? AKFormantFilterAudioUnit

            AKManager.sharedInstance.engine.attachNode(self.avAudioNode)
            input.addConnectionPoint(self)
        }

        guard let tree = internalAU?.parameterTree else { return }

        centerFrequencyParameter = tree.valueForKey("centerFrequency") as? AUParameter
        attackDurationParameter  = tree.valueForKey("attackDuration")  as? AUParameter
        decayDurationParameter   = tree.valueForKey("decayDuration")   as? AUParameter

        token = tree.tokenByAddingParameterObserver {
            address, value in

            dispatch_async(dispatch_get_main_queue()) {
                if address == self.centerFrequencyParameter!.address {
                    self.centerFrequency = Double(value)
                } else if address == self.attackDurationParameter!.address {
                    self.attackDuration = Double(value)
                } else if address == self.decayDurationParameter!.address {
                    self.decayDuration = Double(value)
                }
            }
        }
        centerFrequencyParameter?.setValue(Float(centerFrequency), originator: token!)
        attackDurationParameter?.setValue(Float(attackDuration), originator: token!)
        decayDurationParameter?.setValue(Float(decayDuration), originator: token!)
    }

    /// Function to start, play, or activate the node, all do the same thing
    public func start() {
        self.internalAU!.start()
    }

    /// Function to stop or bypass the node, both are equivalent
    public func stop() {
        self.internalAU!.stop()
    }
}
