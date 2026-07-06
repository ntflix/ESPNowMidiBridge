struct Instrument {
    let name: String
    let midiChannel: Int

    public init(name: String, midiChannel: Int) {
        self.name = name
        self.midiChannel = midiChannel
    }

    static let allInstruments: [Instrument] = [
        Instrument(name: "Dreamy Vox", midiChannel: 1),
        Instrument(name: "Bells", midiChannel: 2),
        Instrument(name: "Charm", midiChannel: 3),
        Instrument(name: "Synth Brass", midiChannel: 4),
        Instrument(name: "Manchester Kit", midiChannel: 5),
        Instrument(name: "Time Bomb", midiChannel: 6),
        Instrument(name: "Charm 2", midiChannel: 7),
        Instrument(name: "Deluxe Modern", midiChannel: 8),
        Instrument(name: "Jazz Fusion Organ", midiChannel: 9),
        Instrument(name: "Vibraphone", midiChannel: 10),
        Instrument(name: "Violins", midiChannel: 11),
        Instrument(name: "Dream Sequence", midiChannel: 12),
        Instrument(name: "Classical Acoustic", midiChannel: 13),
        Instrument(name: "70s Funk Clav", midiChannel: 14),
        Instrument(name: "Ballad", midiChannel: 15),
    ]
}
