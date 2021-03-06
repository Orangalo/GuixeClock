import UIKit

public class Clock: UIView, UIPickerViewDelegate  {
    var words: [String]
    
    var backgroundColorPicker: ChromaColorPicker!
    var clockColorPicker: ChromaColorPicker!
    var handsColorPicker: ChromaColorPicker!
    
    public init() {
        // Initialise default words
        words = [
            "WORK",
            "BELIEF",
            "DESIRE",
            "DESIGN",
            "EMOTION",
            "TECH",
            "APPLE",
            "FOOD",
            "LIFE",
            "PANIC",
            "LOVE",
            "DREAM"
        ]
        
        let frame: CGRect = CGRect(x: 0, y: 0, width: 768, height: 950)
        super.init(frame: frame)
        
        // Initialise pickers and adjust to default colour
        backgroundColorPicker = ChromaColorPicker(frame: CGRect(x: 27, y: 700, width: 238, height: 238))
        // We adjust to the default colour only at the end, so the button is initialised properly
        
        clockColorPicker = ChromaColorPicker(frame: CGRect(x: 265, y: 700, width: 238, height: 238))
        clockColorPicker.adjustToColor(UIColor(rgb: 0x7ec4da))

        handsColorPicker = ChromaColorPicker(frame: CGRect(x: 503, y: 700, width: 238, height: 238))
        handsColorPicker.adjustToColor(UIColor(rgb: 0xedd514))
        
        // Set stroke, delegate and hide unnecessary components. Then, update UI when finish choosing colour and add to subview
        [backgroundColorPicker, clockColorPicker, handsColorPicker].forEach {
            $0!.stroke = 3
            $0!.delegate = self
            $0!.supportsShadesOfGray = true
            $0!.colorToggleButton.addTarget(self, action: #selector(self.update), for: .touchUpInside) // This makes sure that when the greyscale colour button is clicked the screen will update, which doesn't happen by default, because pushing that button doesn't trigger the .editingDidEnd event.
            
            $0!.hexLabel.isHidden = true
            $0!.addButton.isHidden = true
            $0!.handleLine.isHidden = true
            
            $0!.addTarget(self, action: #selector(self.update), for: .editingDidEnd)
            self.addSubview($0!)
        }
        
        // Initialise UILabels for ColorPickers
        let backgroundColorPickerUILabel: UILabel = UILabel(frame: CGRect(x: 93, y: 770, width: 100, height: 100))
        let clockColorPickerUILabel: UILabel = UILabel(frame: CGRect(x: 331, y: 770, width: 100, height: 100))
        let handsColorPickerUILabel: UILabel = UILabel(frame: CGRect(x: 569, y: 770, width: 100, height: 100))
        
        backgroundColorPickerUILabel.text = "BACKGROUND\nCOLOR"
        clockColorPickerUILabel.text = "CLOCK\nCOLOR"
        handsColorPickerUILabel.text = "HANDS\nCOLOR"
        
        [backgroundColorPickerUILabel, clockColorPickerUILabel, handsColorPickerUILabel].forEach {
            $0.textAlignment = .center
            $0.font = getSoWhatFont(size: 25)
            $0.numberOfLines = 0
            self.addSubview($0)
        }
        
        // We do this at the end so that the button press won't crash the program
        backgroundColorPicker.colorToggleButton.sendActions(for: .touchUpInside)
        backgroundColorPicker.adjustToColor(UIColor(rgb: 0x373737))

        update()
        
        // Get closest minute, at which we start a timer which updates the UIView every minute, so that the clock functions as expected from a clock.
        // This way, the clock is precisely identical to the computer's clock.
        let closestMinute: Date = getClosestRoundMinute()
        
        let timer: Timer = Timer(fireAt: closestMinute, interval: 60, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
    }
    
    // Changes a word when the sender, of type UIButton, is clicked
    @objc func changeWord(sender: UIButton) {
        // Create the alert and add a text field to it
        let alert: UIAlertController = UIAlertController(title: "Enter a new word to replace \"\((sender.titleLabel?.text ?? "").capitalized)\" with", message: "If your keyboard is being funky, hold option while clicking the lettter.", preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = "Enter your word here!"
        }
        
        // When Done is pressed, get the value of the text field and put it in the words array, then update.
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { [weak alert] (_) in
            let textField: UITextField = alert!.textFields![0]
            let newWord: String = textField.text!.uppercased()
            textField.autocorrectionType = .no
            
            // Make sure the text entered is non-empty
            if newWord != "" {
                self.words[sender.tag] = newWord
            }
            
            self.update()
        }))
        
        alert.presentInOwnWindow(animated: true, completion: nil)
    }
    
    @objc func update() {
        // Update background colour according to colour picker
        self.backgroundColor = backgroundColorPicker.currentColor
        
        // We must first remove the already-existing layers from the pervious update() call and UILabels
        if self.layer.sublayers != nil {
            self.layer.sublayers!.forEach {
                if let name = $0.name {
                    if ["clockCircle", "minuteHand", "hourHand", "IS"].contains(name) {
                        $0.removeFromSuperlayer()
                    }
                }
            }
        }
        
        // Remove the generated sentence so it can be regenerated. We also remove the label for the word "IS", so that we don't generate another one on top of the already existing one.
        self.subviews.forEach {
            if [99, 199].contains($0.tag) {
                $0.removeFromSuperview()
            }
        }
        
        // Create the clock, which is a circle layer
        let circ: CAShapeLayer = getCircleLayer(x: 384, y: 300, r: 300, color: clockColorPicker.currentColor.cgColor)
        circ.name = "clockCircle"
        circ.shadowOpacity = 1
        circ.shadowRadius = 6
        self.layer.addSublayer(circ)
        
        // Variables for arrow sizes; Described in the PDF file under Sources/main.pdf
        let h: Double = 15.0
        let l1: Double = 170.0
        let d: Double = 25.0
        let k1: Double = 45.0
        let l2: Double = 245.0
        let k2: Double = 15.0
        
        let min: Double = getCurrentMinute()
        let hr: Double = getCurrentHour()
        
        // Create the paths for the clock's hands
        let hourHand: UIBezierPath = createHourHandPath(hr: hr, min: min, h: h, l1: l1, d: d, k1: k1)
        let minuteHand: UIBezierPath = createMinuteHandPath(min: min, h: h, l2: l2, k2: k2)
        
        // Create layers, set properties and add to view
        let hourLayer: CAShapeLayer = CAShapeLayer()
        let minuteLayer: CAShapeLayer = CAShapeLayer()

        hourLayer.path = hourHand.cgPath
        minuteLayer.path = minuteHand.cgPath

        hourLayer.fillColor = handsColorPicker.currentColor.cgColor
        minuteLayer.fillColor = handsColorPicker.currentColor.cgColor

        hourLayer.shadowOpacity = 1
        minuteLayer.shadowOpacity = 1
        hourLayer.shadowRadius = 10
        minuteLayer.shadowRadius = 10
        
        hourLayer.name = "hourHand"
        minuteLayer.name = "minuteHand"
        
        self.layer.addSublayer(hourLayer)
        self.layer.addSublayer(minuteLayer)
        
        // Create the sentence
        let currentMinuteForSentence: Int = Int(getCurrentMinute())
        let currentHourForSentence: Int = Int(getCurrentHour()) - 1
        
        let sentence: UILabel = UILabel(frame: CGRect(x: 84, y: 585, width: 600, height: 100))
        sentence.textAlignment = .center
        
        let firstWordIndex: Int = mod(Int(round(Double(currentMinuteForSentence) / 5.0)) - 1, 12)
        
        // The hour hand word is dependent on whether or not the minute is more than 30
        var secondWordIndex: Int
        secondWordIndex = currentMinuteForSentence <= 30 ? currentHourForSentence : currentHourForSentence + 1
        secondWordIndex = mod(secondWordIndex, 12) // Make sure the index is within range
        
        let firstWord: String = words[firstWordIndex]
        let secondWord: String = words[secondWordIndex]
        
        sentence.text = "\(firstWord) IS \(secondWord)"
        sentence.font = getSoWhatFont(size: 60)
        
        sentence.tag = 99
        
        // We make sure the background isn't too dark. If it is, the text colour is set to white.
        let titleColorForSentence: UIColor = brightness(color: backgroundColorPicker.currentColor) < 0.25 ? .white : .black
        sentence.textColor = titleColorForSentence
        
        self.addSubview(sentence)
        
        // Add the circle behind the word "IS"
        let circleBehindIS: CAShapeLayer = getCircleLayer(x: 384, y: 300, r: 50, color: UIColor(rgb: 0xf2ebd5).cgColor)
        circleBehindIS.shadowOpacity = 1
        circleBehindIS.shadowRadius = 10
        
        self.layer.addSublayer(circleBehindIS)
        
        // Add the rotating "IS" label. Rotation is dependent on the hour arrow's direction, and is therefore calculated with the same formula.
        let labelForIS: UILabel = UILabel(frame: CGRect(x: 354, y: 270, width: 60, height: 60))
        
        labelForIS.text = "IS"
        labelForIS.textAlignment = .center
        labelForIS.font = getSoWhatFont(size: 60)
        labelForIS.tag = 199
        labelForIS.transform = CGAffineTransform(rotationAngle: CGFloat(Double(mod(Int(round(hr * 30 + min / 2)), 360)).degrees()))
        
        self.addSubview(labelForIS)
        
        // We make sure the background isn't too dark. If it is, the text colour is set to white.
        let titleColorForButton: UIColor = brightness(color: clockColorPicker.currentColor) < 0.25 ? .white : .black
        
        // Initialise the buttons with the corresponding words and add the target upon click
        for hr in 1...12 {
            let coords: CGPoint = getCoordinatesOfLabelByHour(hr: hr)
            let button: UIButton = UIButton(frame: CGRect(x: coords.x - 25, y: coords.y - 25, width: 100, height: 50))
            
            button.setTitle(words[hr - 1], for: .normal)
            button.setTitleColor(titleColorForButton, for: .normal)
            button.titleLabel?.font = getSoWhatFont(size: 30)
            button.sizeToFit()
            button.titleLabel!.textAlignment = .center
            
            button.tag = hr - 1
            
            button.addTarget(self, action: #selector(changeWord), for: .touchUpInside)
            
            self.addSubview(button)
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Clock must conform to the ChromaColorPickerDelegate delegate. When a colour is picked, we update the screen.
extension Clock: ChromaColorPickerDelegate {
    public func colorPickerDidChooseColor(_ colorPicker: ChromaColorPicker, color: UIColor) {
        update()
    }
}
