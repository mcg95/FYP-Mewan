//
//  ViewController.swift
//  FYP-Mewan
//
//  Created by Mewan Chathuranga on 02/05/2018.
//  Copyright © 2018 Mewan Chathuranga. All rights reserved.
//

import UIKit
import SpriteKit
import ARKit
import Vision
import GPUImage2
import DGRunkeeperSwitch
import CoreData
import SwiftMessages
import SRCountdownTimer
import SwiftyButton


class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, UIGestureRecognizerDelegate {
    
    // The pixel buffer being held for analysis; used to serialize Vision requests.
    private var currentBuffer: CVPixelBuffer?
    private var currentFrame: ARFrame?
    // Queue for dispatching vision classification requests
    private let visionQueue = DispatchQueue(label: "com.example.apple-samplecode.ARKitVision.serialVisionQueue")
    
    // Classification results
    private var identifierString = ""
    private var confidence: VNConfidence = 0.0
    private var selectedButtonIndex = 0
    var visionRequests = [VNRequest]()
    
    // Labels for classified objects by ARAnchor UUID
    private var anchorLabels = [UUID: String]()
    
    var textMetadata = [Int: [Int: String]]()
    
    let textChecker = UITextChecker()
    var correctStr: String = String()
    private var confidenceThreshold: Double = 0.75
    private var objectConfidenceThreshold: Double = 0.4
    private var totConfidence: VNConfidence = 0.0
    var shouldProcessFrames = true
    var ranFunctionTimer = false
    var englishWord = ""
    var malayWord = ""
    var displayedAnswers: Bool = false
    let bubbleDepth : Float = 0.01 // the 'depth' of 3D text
    var flashOn = false
    var nodePositions = [String: SCNVector3]()
    var translationsCurrently = [String: String]()
    var detectedTextTranslations = [String: String]()
    //SwiftMessages Variables
    var swiftMsgView: MessageView? = nil
    var nodeAdded:Bool = false
    var testScore:Int = 0
    var learningModeEnabled = false
    var tappedNodeName: String?
    var prevResult:String?
    var showImagePreview = false
    var userScores:[Int] = []
    let swiftMessages = SwiftMessagesNotification()
    // If false, test and translation is done from Malay to English. If true, test and translation is done from English to Malay
    var malayEnglishToggle = false
    //CoreData Model Array
    var learntWords = [LearntWords]()
    var currentDetectedWord: String?
    
    var randomMalayWords1 = ["kepala","komputer","epal","beg","bola"]
    var randomMalayWords2 = ["kasut","anjing","kerusi","meja","keretapi"]
    
    var randomEnglishWords1 = ["head","computer","apple","bag","ball"]
    var randomEnglishWords2 = ["shoe","dog","chair","table","train"]
    
    
    
    @IBOutlet weak var detectButtonImage: UIImageView!
    
    @IBOutlet weak var imagePreview: UIImageView!
    
    @IBOutlet weak var sceneView: ARSCNView!
    
    @IBOutlet weak var flashImage: UIImageView!
    @IBOutlet weak var runkeeperSwitch2: DGRunkeeperSwitch?
    
    @IBAction func flashToggle(_ sender: UIButton) {
        if flashOn == false {
            toggleTorch(on: true)
            flashImage.image = #imageLiteral(resourceName: "flashOn")
            flashOn = true
        }else{
            toggleTorch(on: false)
            flashImage.image = #imageLiteral(resourceName: "flashOff")

            learningMode.isHidden = false

        }

    }
    @IBOutlet weak var flashToggleButton: UIButton!
    
    @IBOutlet weak var learningMode: UISwitch!
    
    
    
    @IBAction func switchLearningMode(_ sender: Any) {
        if learningMode.isOn == true{
            learningModeEnabled = true
        } else {
            learningModeEnabled = false
        }
    }
    @IBOutlet weak var countdownLabel: SRCountdownTimer!
    
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var sideView: UIView!
    
    @IBOutlet weak var startTestButton: PressableButton!
    @IBAction func testButton(_ sender: Any) {
        var shuffledRandomWords1: [String]?
        var shuffledRandomWords2: [String]?
         if selectedButtonIndex == 1 {
        if sceneView.scene.rootNode.childNodes.count > 0{
        testScore = 0
        learningModeEnabled = false
        learningMode.isEnabled = false
        for nodePos in nodePositions{
            // Create 3D Text
        
            
            if malayEnglishToggle == false{
             shuffledRandomWords1 = randomMalayWords1.shuffle()
            shuffledRandomWords2 = randomMalayWords2.shuffle()
            } else{
                shuffledRandomWords1 = randomEnglishWords1.shuffle()
                shuffledRandomWords2 = randomEnglishWords2.shuffle()
            }
            var correctAnswer: String = ""
            for translations in translationsCurrently{
                if nodePos.key == translations.key{
                    correctAnswer = translations.value
                    print("nodePos.key and translations.key match")
                }
            }
            var answerList:[String] = ["\(shuffledRandomWords1!.chooseOne)","\(shuffledRandomWords2!.chooseOne)"]
            var shuffledAnswerList = answerList.shuffle()
            let qNode1 : SCNNode = self.createNewBubbleParentNode(answerList[0])
            let qNode2 : SCNNode = self.createNewBubbleParentNode(answerList[1])
            let qNode3 : SCNNode = self.createNewBubbleParentNode(correctAnswer)

            var nodePosShuffleArray = [SCNVector3Make(nodePos.value.x , nodePos.value.y + 0.1, nodePos.value.z),SCNVector3Make(nodePos.value.x , nodePos.value.y - 0.1, nodePos.value.z), SCNVector3Make(nodePos.value.x , nodePos.value.y, nodePos.value.z)]
            var shuffledNodePos = nodePosShuffleArray.shuffle()

            qNode1.position = shuffledNodePos[0]
            qNode2.position = shuffledNodePos[1]
            qNode3.position = shuffledNodePos[2]
            
            qNode1.name = answerList[0]
            qNode2.name = answerList[1]
            qNode3.name = "Correct Answer"
            
            self.sceneView.scene.rootNode.addChildNode(qNode1)
            self.sceneView.scene.rootNode.addChildNode(qNode2)
            self.sceneView.scene.rootNode.childNodes.filter({ $0.name == nodePos.key }).forEach({ $0.removeFromParentNode() })
            self.sceneView.scene.rootNode.addChildNode(qNode3)
            
        }
        startTestButton.isHidden = true
        stopTestButton.isHidden = false
            setupScoreboard()
            
        }else{
            print("No Nodes Detected in Environment")
            }
            
         } else{
            
            if sceneView.scene.rootNode.childNodes.count > 0{
                testScore = 0
                learningModeEnabled = false
                learningMode.isEnabled = false
                for nodePos in nodePositions{
                    // Create 3D Text
                    if malayEnglishToggle == false{
                        shuffledRandomWords1 = randomMalayWords1.shuffle()
                        shuffledRandomWords2 = randomMalayWords2.shuffle()
                    } else{
                        shuffledRandomWords1 = randomEnglishWords1.shuffle()
                        shuffledRandomWords2 = randomEnglishWords2.shuffle()
                    }
                    var correctAnswer: String = ""
                    DispatchQueue.global().async {
                        for translations in self.detectedTextTranslations{
                            if nodePos.key == translations.key{
                                correctAnswer = translations.value
                                print("nodePos.key and translations.key match")
                            }
                        }
                    }
                    
                    var answerList:[String] = ["\(shuffledRandomWords1!.chooseOne)","\(shuffledRandomWords2!.chooseOne)"]
                    var shuffledAnswerList = answerList.shuffle()
                    let qNode1 : SCNNode = self.createNewBubbleParentNode(answerList[0])
                    let qNode2 : SCNNode = self.createNewBubbleParentNode(answerList[1])
                    let qNode3 : SCNNode = self.createNewBubbleParentNode(correctAnswer)
                    
                    var nodePosShuffleArray = [SCNVector3Make(nodePos.value.x , nodePos.value.y + 0.1, nodePos.value.z),SCNVector3Make(nodePos.value.x , nodePos.value.y - 0.1, nodePos.value.z), SCNVector3Make(nodePos.value.x , nodePos.value.y, nodePos.value.z)]
                    var shuffledNodePos = nodePosShuffleArray.shuffle()
                    
                    qNode1.position = shuffledNodePos[0]
                    qNode2.position = shuffledNodePos[1]
                    qNode3.position = shuffledNodePos[2]
                    
                    qNode1.name = answerList[0]
                    qNode2.name = answerList[1]
                    qNode3.name = "Correct Answer"
                    
                    self.sceneView.scene.rootNode.addChildNode(qNode1)
                    self.sceneView.scene.rootNode.addChildNode(qNode2)
                    self.sceneView.scene.rootNode.childNodes.filter({ $0.name == nodePos.key }).forEach({ $0.removeFromParentNode() })
                    self.sceneView.scene.rootNode.addChildNode(qNode3)
                }
                startTestButton.isHidden = true
                stopTestButton.isHidden = false
                setupScoreboard()
            }else{
                print("No Nodes Detected in Environment")
            }
        }
    }
    
    @IBOutlet weak var startDetect: UIButton!
    @IBAction func startDetectButton(_ sender: Any) {
        shouldProcessFrames = true
        stopDetect.isHidden = false
        startDetect.isHidden = true
        detectButtonImage.image = #imageLiteral(resourceName: "PauseScan")
    }
    @IBOutlet weak var stopDetect: UIButton!
    
    @IBAction func stopDetectButton(_ sender: Any) {
        var result: String = (currentDetectedWord?.lowercased())!
        
            stopDetect.isHidden = true
            startDetect.isHidden = false
        self.shouldProcessFrames = false
        detectButtonImage.image = #imageLiteral(resourceName: "StartScan")
        let textChecker = UITextChecker()
        let misspelledRange = textChecker.rangeOfMisspelledWord(
            in: result, range: NSRange(0..<result.count), startingAt: 0, wrap: false, language: "en_US")
        
        if misspelledRange.location != NSNotFound,
            let guesses = textChecker.guesses(forWordRange: misspelledRange, in: result, language: "en_US") {
            if guesses.first != nil{
                correctStr = guesses.first!
                print("Corrected Result: " + correctStr)
                self.englishWord = correctStr
                checkForTextCoreData(correctStr: correctStr)
                self.prevResult = correctStr
            } else {
                swiftMessages.displayNotification(layout: .cardView, title: "Error", body: "No words found in detected letters! Please try again!", presentationStyle: .bottom, iconText: "⚠️", backgroundColor: UIColor.init(red: 255, green: 0, blue: 0, alpha: 0.8))
            }
            
            
        }
    }
    
    func checkForObjectCoreData(objectName: String){
        let wordModel = LearntWords(context: CoreDataService.context)
        //wordModel.englishword = objectName
        let detectedWord = learntWords.filter{ $0.englishword == objectName }
        let wordExists = detectedWord.isEmpty
        if wordExists == false{
            
            self.shouldProcessFrames = false
            for word in learntWords{
                if word.malayword == nil{
                    
                }else{
                    malayWord = word.malayword!
                    englishWord = word.englishword!
                }
            }
            
            print("Node added from CoreData!")
            addNodeForObjectClassification()
          
        }else if wordExists == true{
            self.shouldProcessFrames = false
            swiftMessages.displayNotification(layout: .cardView, title: "New Word", body: "Saved into Local Data", presentationStyle: .top, iconText: "✅", backgroundColor: UIColor.init(red: 0/255.0, green: 204.0/255.0, blue: 102.0/255.0, alpha: 0.8))
            
            translateTextToMalay(text2Translate: englishWord)
           
        }
       
    }
    func checkForTextCoreData(correctStr: String){
        let wordModel = LearntWords(context: CoreDataService.context)
        //wordModel.englishword = correctStr
        //let tempSave = LearntWords(context: CoreDataService.context)
        let detectedWord = learntWords.filter{ $0.englishword == correctStr }
        let wordExists = detectedWord.isEmpty
        if wordExists == false{
            
            self.shouldProcessFrames = false
            for word in detectedWord{
                if word.malayword == nil{
                    
               
                    
                }else{
                    malayWord = word.malayword!
                    englishWord = word.englishword!
                }
               //word.englishword?.removeAll()
               //word.malayword?.removeAll()
               //CoreDataService.saveContext()
            }
            print("Node added from CoreData!")
            addNodeforTextClassification()
            
        }else if wordExists == true{
            self.shouldProcessFrames = false
            swiftMessages.displayNotification(layout: .cardView, title: "New Word", body: "Saved into Local Data", presentationStyle: .top, iconText: "✅", backgroundColor: UIColor.init(red: 0/255.0, green: 204.0/255.0, blue: 102.0/255.0, alpha: 0.8))

 
           translateTextToMalay(text2Translate: correctStr)
            
        }
    }
    
  
    @IBOutlet weak var stopTestButton: PressableButton!
    @IBAction func stopTestButton(_ sender: Any) {
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
            
        }
        stopTestButton.isHidden = true
        startTestButton.isHidden = false
        
        let userDefaults = UserDefaults.standard
        userDefaults.setValue(testScore, forKey: "score")
        userDefaults.synchronize()
        if userDefaults.data(forKey: "score") != nil{
        userScores = userDefaults.array(forKey: "score") as! [Int]
        print(userScores)
        }
    }
    @IBAction func modeToggleValueDidChange(sender: DGRunkeeperSwitch!) {
        selectedButtonIndex = sender.selectedIndex
        if sender.selectedIndex == 1{
            shouldProcessFrames = false
            print("Started processing frames")
            startDetect.isHidden = false
            stopDetect.isHidden = true
        }else{
            shouldProcessFrames = false
            startDetect.isHidden = false
            stopDetect.isHidden = true
        }
        print("valueChanged: \(sender.selectedIndex)")
    }
    @IBAction func langToggleValueDidChange(sender: DGRunkeeperSwitch!) {
        if sender.selectedIndex == 0{
            malayEnglishToggle = false
            print("Malay English Toggle: \(malayEnglishToggle)")
            
        } else if sender.selectedIndex == 1{
            malayEnglishToggle = true
            print("Malay English Toggle: \(malayEnglishToggle)")

        }
    }
    
    @IBOutlet weak var imagePreviewToggle: UISwitch!
    
    @IBAction func imagePreviewToggleValueDidChange(_ sender: Any) {
        if imagePreviewToggle.isOn == false{
            imagePreview.isHidden = true
        }else{
            showImagePreview = true
            imagePreview.isHidden = false

        }
    }
  
    
    // The view controller that displays the status and "restart experience" UI.
    private lazy var statusViewController: StatusViewController = {
        return childViewControllers.lazy.flatMap({ $0 as? StatusViewController }).first!
    }()
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        if #available(iOS 11.3, *) {
            configuration.isAutoFocusEnabled = true
        } else {
            // Fallback on earlier versions
        }
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        
        // Show statistics such as fps and node count
        let overlayScene = SCNScene()
      //  overlayScene.scaleMode = .aspectFill
        sceneView.delegate = self
        sceneView.scene = overlayScene
        //sceneView.presentScene(overlayScene)
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        totConfidence = 0.0
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(sender:)))
        view.addGestureRecognizer(tapGestureRecognizer)
        
        
        startTestButton.colors = .init(button: .green, shadow: .black)
        startTestButton.cornerRadius = 10
        startTestButton.isHidden = false
        startTestButton.titleLabel?.text = "Start Test"
        stopTestButton.colors = .init(button: .red, shadow: .black)
        startTestButton.titleLabel?.text = "Stop Test"
        stopTestButton.isHidden = true
        stopDetect.isHidden = true
        startDetect.isHidden = false
        shouldProcessFrames = false
        let userDefaults = UserDefaults.standard
        if userDefaults.data(forKey: "score") != nil {
        userScores = userDefaults.array(forKey: "score") as! [Int]
        }
        
        statusViewController.restartExperienceHandler = { [unowned self] in self.restartSession()}
        learningMode.isOn = false
        setupModeToggle()
        setupLangToggle()
        countdownLabel.isHidden = true
        flashImage.image = #imageLiteral(resourceName: "flashOff")
        imagePreview.isHidden = true
        detectButtonImage.image = #imageLiteral(resourceName: "StartScan")
        setupSlideInMenu()
        guard let objectModel = try? VNCoreMLModel(for: Inceptionv3().model) else {
            fatalError("can't load Object model")
        }
        fetchLearntWordsCoreData()
     
    }
    
    func setupSlideInMenu(){
        blurView.layer.cornerRadius = 15
        sideView.layer.shadowColor = UIColor.black.cgColor
        sideView.layer.shadowOpacity = 0.8
        sideView.layer.shadowOffset = CGSize(width: 5, height: 0)
        leadingConstraint.constant = -260
    }
    
    func fetchLearntWordsCoreData(){
        let fetchRequest:NSFetchRequest<LearntWords> = LearntWords.fetchRequest()
        
        do{
            let lWords = try CoreDataService.context.fetch(fetchRequest)
            self.learntWords = lWords
            
        }
        catch{
            print("CoreDataService Fetch Request Failed")
        }
    }
    @IBAction func panPerformed(_ sender: UIPanGestureRecognizer) {
        
        if sender.state == .began || sender.state == .changed{
            
            let translation = sender.translation(in: self.view).x
            if translation > 0 {
                
                if leadingConstraint.constant < 20 {
                    UIView.animate(withDuration: 0.2) {
                        self.leadingConstraint.constant += translation / 10
                        self.view.layoutIfNeeded()
                    }
                }
                
            } else {
                
                if leadingConstraint.constant > -260 {
                    UIView.animate(withDuration: 0.2) {
                        self.leadingConstraint.constant += translation / 10
                        self.view.layoutIfNeeded()
                    }
                }
            }
            
        }else if sender.state == .ended{
            
            if leadingConstraint.constant < -100 {
                UIView.animate(withDuration: 0.2) {
                    self.leadingConstraint.constant = -260
                    self.view.layoutIfNeeded()
                }
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.leadingConstraint.constant = 0
                    self.view.layoutIfNeeded()
                }
            }
            
        }
        
    }
    func setupModeToggle(){
        let runkeeperSwitch2 = DGRunkeeperSwitch()
        runkeeperSwitch2.titles = ["Text", "Objects"]
        runkeeperSwitch2.backgroundColor = UIColor(red: 239.0/255.0, green: 95.0/255.0, blue: 49.0/255.0, alpha: 1.0)
        runkeeperSwitch2.selectedBackgroundColor = .white
        runkeeperSwitch2.titleColor = .white
        runkeeperSwitch2.selectedTitleColor = UIColor(red: 239.0/255.0, green: 95.0/255.0, blue: 49.0/255.0, alpha: 1.0)
        runkeeperSwitch2.titleFont = UIFont(name: "HelveticaNeue-Medium", size: 13.0)
        runkeeperSwitch2.frame = CGRect(x: 20.0, y: 36.0, width: sideView.bounds.width - 50.0, height: 30.0)
        runkeeperSwitch2.autoresizingMask = [.flexibleWidth] // This is needed if you want the control to resize
        sideView.addSubview(runkeeperSwitch2)

        runkeeperSwitch2.addTarget(self, action: #selector(ViewController.modeToggleValueDidChange(sender:)), for: .valueChanged )
    }
    func setupLangToggle(){
        let runkeeperSwitch2 = DGRunkeeperSwitch()
        runkeeperSwitch2.titles = ["MLY-ENG", "ENG-MLY"]
        runkeeperSwitch2.backgroundColor = UIColor(red: 239.0/255.0, green: 95.0/255.0, blue: 49.0/255.0, alpha: 1.0)
        runkeeperSwitch2.selectedBackgroundColor = .white
        runkeeperSwitch2.titleColor = .white
        runkeeperSwitch2.selectedTitleColor = UIColor(red: 239.0/255.0, green: 95.0/255.0, blue: 49.0/255.0, alpha: 1.0)
        runkeeperSwitch2.titleFont = UIFont(name: "HelveticaNeue-Medium", size: 13.0)
        runkeeperSwitch2.frame = CGRect(x: 20.0, y: 100.0, width: sideView.bounds.width - 50.0, height: 30.0)
        runkeeperSwitch2.autoresizingMask = [.flexibleWidth] // This is needed if you want the control to resize
        sideView.addSubview(runkeeperSwitch2)
        
        runkeeperSwitch2.addTarget(self, action: #selector(ViewController.langToggleValueDidChange(sender:)), for: .valueChanged )
    }
    
    func setupScoreboard(){
       
        if (self.sceneView.defaultCameraController.pointOfView?.childNodes.isEmpty)!{
            let worldCoord : SCNVector3 =  (self.sceneView.defaultCameraController.pointOfView?.position)!
            
            
            let node : SCNNode = self.createNewBubbleParentNode("Score: \(String(testScore))")
          //  node.position = SCNVector3(worldCoord.x + 0.3, worldCoord.y, worldCoord.z - 1)
            node.position = SCNVector3( 0, 0.3, -1)

            node.name = "Scoreboard"
            self.sceneView.defaultCameraController.pointOfView?.addChildNode(node)
            
        }else {
             self.sceneView.defaultCameraController.pointOfView?.childNodes.filter({ $0.name == "Scoreboard" }).forEach({ $0.removeFromParentNode() })
            
            
            let worldCoord : SCNVector3 =  (self.sceneView.defaultCameraController.pointOfView?.position)!
            
            
            let node : SCNNode = self.createNewBubbleParentNode("Score: \(String(testScore))")
           // node.position = SCNVector3(worldCoord.x + 0.3, worldCoord.y, worldCoord.z - 1)
            node.position = SCNVector3( 0, 0.3, -1)

            node.name = "Scoreboard"
            self.sceneView.defaultCameraController.pointOfView?.addChildNode(node)
        }

    }
    func updateScore(){
        self.sceneView.defaultCameraController.pointOfView?.childNodes.filter({ $0.name == "Scoreboard" }).forEach({ $0.removeFromParentNode() })
        
        let worldCoord : SCNVector3 =  (self.sceneView.defaultCameraController.pointOfView?.position)!
        
        
        let node : SCNNode = self.createNewBubbleParentNode("Score: \(String(testScore))")
        //node.position = SCNVector3(worldCoord.x + 0.1, worldCoord.y, worldCoord.z - 1)
        node.position = SCNVector3( 0, 0.3, -1)

        node.name = "Scoreboard"
        self.sceneView.defaultCameraController.pointOfView?.addChildNode(node)
        
    }
    
    @objc func handleTap(sender: UITapGestureRecognizer){
        let touchLocation = sender.location(in: sceneView)
        let hitTestResult = sceneView.hitTest(touchLocation, options: [:])
        if !hitTestResult.isEmpty{
            for result in hitTestResult{
                if learningModeEnabled == true {
                    tappedNodeName = result.node.parent?.name
                    showLearningModeText()
                } else {
                    if result.node.parent?.name == "Correct Answer"{
                        testScore += 1
                        print("Score = ", testScore)
                        updateScore()

                }
                print("Parent - Node Name: ", result.node.parent?.name)
                print ("Parent - Node Position: ", result.node.parent?.position)
                }
            }
        }
    }

    func showLearningModeText(){
        swiftMessages.displayNotification(layout: .statusLine, title: "True", body: "\((tappedNodeName)!)", presentationStyle: .top, iconText: "✅", backgroundColor: UIColor.init(red: 0/255.0, green: 204.0/255.0, blue: 102.0/255.0, alpha: 0.8))

   
        print("Learning Mode Node Touched")
    }
    
    private func restartSession(){
        sceneView.delegate?.sessionInterruptionEnded!(sceneView.session)
        let configuration = ARWorldTrackingConfiguration()
        
    }
    
    
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard currentBuffer == nil, case .normal = frame.camera.trackingState else{
            return
        }
        
        currentFrame = frame
        visionQueue.async {
            do{
               
                // Release the pixel buffer when done, allowing the next buffer to be processed.
                defer { self.currentBuffer = nil }
                self.currentBuffer = frame.capturedImage
                self.convertPixelBuffer(cvPixelBuffer: self.currentBuffer!)
               
            } catch {
                print("Error: Vision request failed with error \"\(error)\"")
            }
        }
        
    }
    
    
    
    private func convertPixelBuffer(cvPixelBuffer: CVPixelBuffer){
        var ciImage = CIImage(cvPixelBuffer: currentBuffer!)
        var temporaryContext = CIContext(options: nil)
        var videoImage = temporaryContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(cvPixelBuffer), height: CVPixelBufferGetHeight(cvPixelBuffer)))
        var uiImage: UIImage? = nil
        if let anImage = videoImage {
            uiImage = UIImage(cgImage: anImage)
        }
        if selectedButtonIndex == 0 {
            if shouldProcessFrames == true{
                
                self.detectText(image: uiImage!)

                
            } else if shouldProcessFrames == false{
                print("Frame processing halted!")
            }
            
        }
        else if selectedButtonIndex == 1{
            if shouldProcessFrames == true{
                 DispatchQueue.main.async {
                    
                }
                setupVision()
                
                
            } else if shouldProcessFrames == false{
                DispatchQueue.main.async {
                    self.detectButtonImage.image = #imageLiteral(resourceName: "StartScan")
                    self.startDetect.isHidden = false
                    self.stopDetect.isHidden = true
                }
               
               /* if ranFunctionTimer == false {
                    DispatchQueue.main.async {
                        self.countdownLabel.isHidden = false
                        self.countdownLabel.timerFinishingText = "Restarted"
                        self.countdownLabel.isOpaque = false
                        self.countdownLabel.backgroundColor = UIColor.white.withAlphaComponent(0.1)
                        self.countdownLabel.labelTextColor = UIColor.red
                        self.countdownLabel.lineWidth = 4
                        self.countdownLabel.lineColor = UIColor.red
                        self.countdownLabel.start(beginingValue: 5, interval: 1)

                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                        self.shouldProcessFrames = true
                        print("Restarted Processing Frames")
                        self.ranFunctionTimer = false
                        self.countdownLabel.isHidden = true
                    })
                    ranFunctionTimer = true

                } else{
                    print("Wait for frames to restart processing")
                }*/
            }
        }
    }
    
    func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video)
            else {return}
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if on == true {
                    device.torchMode = .on // set on
                    flashOn = true
                } else {
                    device.torchMode = .off // set off
                    flashOn = false

                }
                
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
        } else {
            print("Torch is not available")
        }
    }
    
    private func detectText(image: UIImage){
        let toProcessImg =  image
        let luminanceFilter = LuminanceThreshold()
        luminanceFilter.threshold = 0.5
        let filteredImg = toProcessImg.filterWithOperation(luminanceFilter)
        let filteredImgFinal = filteredImg.rotate(radians: .pi/2)
        //AdaptiveThreshold
        let handler = VNImageRequestHandler(cgImage: filteredImg.cgImage!)
        DispatchQueue.main.async {
            self.imagePreview.image = filteredImgFinal
            
        }
        if shouldProcessFrames == true{
            
            let request: VNDetectTextRectanglesRequest =
                VNDetectTextRectanglesRequest(completionHandler: { [unowned self] (request, error) in
                    if (error != nil) {
                        print("Got Error In Run Text Dectect Request :(")
                    } else {
                        guard let results = request.results as? Array<VNTextObservation> else {
                            fatalError("Unexpected result type from VNDetectTextRectanglesRequest")
                        }
                        if (results.count == 0) {
                            self.handleEmptyResults()
                            return
                        }
                        var numberOfWords = 0
                        for textObservation in results {
                            var numberOfCharacters = 0
                            for rectangleObservation in textObservation.characterBoxes! {
                                let croppedImage = crop(image: image, rectangle: rectangleObservation)
                                if let croppedImage = croppedImage {
                                    //let processedImage = preProcess(image: croppedImage)
                                    
                                    self.classificationRequest(image: croppedImage,
                                                               wordNumber: numberOfWords,
                                                               characterNumber: numberOfCharacters)
                                    numberOfCharacters += 1
                                }
                            }
                            numberOfWords += 1
                        }
                    }
                })
            request.reportCharacterBoxes = true
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
            
            
        } else if shouldProcessFrames == false{
            if ranFunctionTimer == false {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                    
                    self.shouldProcessFrames = true
                    print("Restarted Processing Frames")
                    self.ranFunctionTimer = false
                })
                ranFunctionTimer = true
            } else{
                
                print("Wait for frames to restart processing")
            }
            
        }
        
    }
    
    private func classificationRequest(image: UIImage, wordNumber: Int, characterNumber: Int){
        
        let luminanceFilter = LuminanceThreshold()
        luminanceFilter.threshold = 0.5
        let processedImg = image.filterWithOperation(luminanceFilter)
        // Instantiate the model from its generated Swift class.
        DispatchQueue.main.async {
            
            self.imagePreview.image = processedImg
            
        }
        let model = try? VNCoreMLModel(for: OCR().model)
        let request = VNCoreMLRequest(model: model!) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation],
                let topResult = results.first(where: {result in result.confidence > 0.9}) else {
                    // fatalError("Unexpected result type from VNCoreMLRequest")
                    self?.identifierString = ""
                    return            }
            let result = topResult.identifier
            let classificationInfo: [String: Any] = ["wordNumber" : wordNumber,
                                                     "characterNumber" : characterNumber,
                                                     "class" : result]
         
            self?.handleResult(classificationInfo)

        }
        guard let ciImage = CIImage(image: processedImg) else {
            fatalError("Could not convert UIImage to CIImage :(")
        }
        // Crop input images to square area at center, matching the way the ML model was trained.
        request.imageCropAndScaleOption = .centerCrop
        
        // Use CPU for Vision processing to ensure that there are adequate GPU resources for rendering.
        request.usesCPUOnly = true
       // let orientation = CGImagePropertyOrientation(UIDevice.current.orientation)
        
        let handler = VNImageRequestHandler(ciImage: ciImage)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            }
            catch {
                print(error)
            }
        }
        
    }
    
    
    
    func handleResult(_ result: [String: Any]) {
        objc_sync_enter(self)
        guard let wordNumber = result["wordNumber"] as? Int else {
            return
        }
        guard let characterNumber = result["characterNumber"] as? Int else {
            return
        }
        guard let characterClass = result["class"] as? String else {
            return
        }
        if (textMetadata[wordNumber] == nil) {
            let tmp: [Int: String] = [characterNumber: characterClass]
            textMetadata[wordNumber] = tmp
        } else {
            var tmp = textMetadata[wordNumber]!
            tmp[characterNumber] = characterClass
            textMetadata[wordNumber] = tmp
        }
        objc_sync_exit(self)
        DispatchQueue.main.async {
            
            self.displayClassifierResults()
        }
    }
    
    private func handleEmptyResults() {
        DispatchQueue.main.async {
            //self.detectedText.text = "The image does not contain any text."
        }
        
    }
    
    private func displayClassifierResults() {
        var result: String = ""
        if (textMetadata.isEmpty) {
            let errMsg = "The image does not contain any text."
            statusViewController.showMessage(errMsg)
            return
        }
        let sortedKeys = textMetadata.keys.sorted()
        
        for sortedKey in sortedKeys {
            result +=  word(fromDictionary: textMetadata[sortedKey]!) + " "
        }
        currentDetectedWord = result
        
        
        statusViewController.showMessage(result)

         }
    

        
    
    
    func word(fromDictionary dictionary: [Int : String]) -> String {
        let sortedKeys = dictionary.keys.sorted()
        var word: String = ""
        for sortedKey in sortedKeys {
            let char: String = dictionary[sortedKey]!
            word += char
        }
        return word
    }
    
    
    
    //Object Detection Model
    
    func setupVision() {
        let model = try? VNCoreMLModel(for: Inceptionv3().model)
        let classificationRequest = VNCoreMLRequest(model: model! , completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
        visionRequests = [classificationRequest]
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        let uIImage = UIImage(ciImage: ciImage)
        let rotatedImgFinal = uIImage.rotate(radians: .pi/2)

        DispatchQueue.main.async {
            //self.imagePreview.image = rotatedImgFinal

        }

        
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        // Run Vision Image Request
        do {
            try imageRequestHandler.perform(self.visionRequests)

        } catch {
            print(error)
        }
        
        
        
    }
    
    
    /// Handle results of the classification request
    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        print("running frames")
        var shouldTranslateWord: Bool = false
        var result = ""
        DispatchQueue.global().async {
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        
        guard let results = request.results as? [VNClassificationObservation],
            let topResult = results.first(where: {result in result.confidence > 0.5}) else {
                // fatalError("Unexpected result type from VNCoreMLRequest")
                self.identifierString = ""
                return            }
        
        let classificationInfo: [String: Any] = ["wordNumber" : topResult.identifier,
                                                 "characterNumber" : String(format:" : %.2f", topResult.confidence)]
        // Get Classification
        
        result = topResult.identifier
            let englishWordArray = result.components(separatedBy: ", ")
            let trimmedEnglishWord = englishWordArray[0]
            self.englishWord = trimmedEnglishWord
            
          
            self.checkForObjectCoreData(objectName: trimmedEnglishWord)
            
       
        }

        
        let englishWordArray = result.components(separatedBy: ", ")
        let trimmedEnglishWord = englishWordArray[0]
        self.englishWord = trimmedEnglishWord
        if nodeAdded == false {
        nodeAdded = true
        } else {
            print("Node already in AR Environment")
        }
        
        
        
        
        // Render Classifications
        
    }
    func addNodeforTextClassification(){
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.2
        let transform = simd_mul(self.currentFrame!.camera.transform , translation)
        
        let worldCoord : SCNVector3 =  SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        // Create 3D Text
        
        if malayEnglishToggle == false{
            let node : SCNNode = self.createNewBubbleParentNode(malayWord)
            node.name = self.correctStr
            //node.position = SCNVector3(0,0,-0.2)
            node.position = worldCoord
            self.nodePositions[self.correctStr] = node.position
            self.sceneView.scene.rootNode.addChildNode(node)
        } else if malayEnglishToggle == true {
            let node : SCNNode = self.createNewBubbleParentNode(self.englishWord)
            node.name = self.malayWord
            node.position = worldCoord
            //node.position = SCNVector3(0,0,-0.2)
            
            self.nodePositions[self.englishWord] = node.position
            self.sceneView.scene.rootNode.addChildNode(node)
          }
        
        //pointOfView?.addChildNode(node)
        self.nodeAdded = false
        //  print("Node Name: ", self.nodePositions.index(forKey: topResult.identifier))
        for nodePos in self.nodePositions{
            
            print("Node Pos Key: ", nodePos.key)
            print("Node Pos Value: ", nodePos.value)
            
        }
    }
    func addNodeForObjectClassification(){
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.2
        let transform = simd_mul(self.currentFrame!.camera.transform , translation)
        
        let worldCoord : SCNVector3 =  SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        // Create 3D Text
        
        if malayEnglishToggle == false{
            let node : SCNNode = self.createNewBubbleParentNode(self.malayWord)
            node.name = self.englishWord
            //node.position = SCNVector3(0,0,-0.2)
            node.position = worldCoord
            self.nodePositions[self.englishWord] = node.position
            self.sceneView.scene.rootNode.addChildNode(node)
        } else if malayEnglishToggle == true {
            let node : SCNNode = self.createNewBubbleParentNode(self.englishWord)
            node.name = self.malayWord
            node.position = worldCoord
            //node.position = SCNVector3(0,0,-0.2)

            self.nodePositions[self.englishWord] = node.position
            self.sceneView.scene.rootNode.addChildNode(node)
        }
        
        //pointOfView?.addChildNode(node)
        self.nodeAdded = false
        //  print("Node Name: ", self.nodePositions.index(forKey: topResult.identifier))
        for nodePos in self.nodePositions{
            
            print("Node Pos Key: ", nodePos.key)
            print("Node Pos Value: ", nodePos.value)
            
        }
    }
    
  
    
    func translateTextToMalay(text2Translate: String){
        struct encodeText: Codable {
            var text = String()
        }
        let azureKey = "4ab01c02ee364f82ade642537439c4d3"
        let contentType = "application/json"
        let traceID = "A14C9DB9-0DED-48D7-8BBE-C517A1A8DBB0"
        let host = "dev.microsofttranslator.com"
        let apiURL = "https://dev.microsofttranslator.com/translate?api-version=3.0&from=en&to=ms"
        var encodeTextSingle = encodeText()
        var toTranslate = [encodeText]()
        
        encodeTextSingle.text = text2Translate
        toTranslate.append(encodeTextSingle)
        
        let encoder = JSONEncoder()
        let jsonToTranslate = try? encoder.encode(toTranslate)
        let url = URL(string: apiURL)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.addValue(azureKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        request.addValue(traceID, forHTTPHeaderField: "X-ClientTraceID")
        request.addValue(host, forHTTPHeaderField: "Host")
        request.addValue(String(describing: jsonToTranslate?.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = jsonToTranslate
        
        let config = URLSessionConfiguration.default
        let session =  URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { (responseData, response, responseError) in
            
            if responseError != nil {
                print("this is the error ", responseError!)
                
                let alert = UIAlertController(title: "Could not connect to service", message: "Please check your network connection and try again", preferredStyle: .actionSheet)
                
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                
                self.present(alert, animated: true)
                
            }
            print("*****")
            self.parseJson(jsonData: responseData!)
        }
        task.resume()
    }
    
    
    
    func parseJson(jsonData: Data) {
        
        //*****TRANSLATION RETURNED DATA*****
        struct ReturnedJson: Codable {
            var translations: [TranslatedStrings]
        }
        struct TranslatedStrings: Codable {
            var text: String
            var to: String
        }
        
        let jsonDecoder = JSONDecoder()
        let langTranslations = try? jsonDecoder.decode(Array<ReturnedJson>.self, from: jsonData)
        let numberOfTranslations = langTranslations!.count - 1
        print(langTranslations!.count)
        
        //Put response on main thread to update UI
        let translatedWordArray = langTranslations![0].translations[numberOfTranslations].text
            //.components(separatedBy: ", ")
        let trimmedTranslatedWord = translatedWordArray
        
        let wordModel = LearntWords(context: CoreDataService.context)
        malayWord = trimmedTranslatedWord

       
        
        
        
        if selectedButtonIndex == 1{
            wordModel.englishword = englishWord
            wordModel.malayword = trimmedTranslatedWord
            translationsCurrently[englishWord] = trimmedTranslatedWord
            addNodeForObjectClassification()
                
            
        }else{
            wordModel.englishword = correctStr
            wordModel.malayword = trimmedTranslatedWord
            detectedTextTranslations[correctStr] = trimmedTranslatedWord
            addNodeforTextClassification()

        }
        
     
        self.learntWords.append(wordModel)
        CoreDataService.saveContext()
        

      
    

    }
    
 
    func saveToCoreData(){
       
        CoreDataService.saveContext()
        DispatchQueue.main.async {
            self.statusViewController.showMessage("Malay:" + self.malayWord + " English: " + self.englishWord)
        }
    }
 
    //CLASS
    func createNewBubbleParentNode(_ text : String) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // BUBBLE-TEXT
        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        var font = UIFont(name: "Futura", size: 0.15)
        font = font?.withTraits(traits: .traitBold)
        bubble.font = font
        bubble.alignmentMode = kCAAlignmentCenter
        bubble.firstMaterial?.diffuse.contents = UIColor.orange
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        // bubble.flatness // setting this too low can cause crashes.
        bubble.chamferRadius = CGFloat(bubbleDepth)
        
        // BUBBLE NODE
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        // CENTRE POINT NODE
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)
        
        // BUBBLE PARENT NODE
        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(bubbleNode)
        bubbleNodeParent.addChildNode(sphereNode)
        bubbleNodeParent.constraints = [billboardConstraint]
        
        return bubbleNodeParent
    }
    
    @IBOutlet weak var answerOne: UIButton!
    @IBOutlet weak var answerTwo: UIButton!
    @IBOutlet weak var answerThree: UIButton!
    
    @IBOutlet var answerButtons: [UIButton]!
    

    // MARK: - ARSKViewDelegate
    
    func view(_ view: ARSCNView, nodeFor anchor: ARAnchor) -> SKNode? {
        // Create and configure a node for the anchor added to the view's session.
        
        guard let identifier = ARShared.shared.anchorsToIdentifiers[anchor] else {
            return nil
        }
   
        let labelNode = SKLabelNode(text: "")
   
        return labelNode
        
        
        
        
        
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Filter out optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
      //  setOverlaysHidden(true)
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        /*
         Allow the session to attempt to resume after an interruption.
         This process may not succeed, so the app must be prepared
         to reset the session if the relocalizing status continues
         for a long time -- see `escalateFeedback` in `StatusViewController`.
         */
        return true
    }
    
    
    
    
    
    // Show the classification results in the UI.
 
    func view(_ view: ARSKView, didAdd node: SKNode, for anchor: ARAnchor) {
        guard let labelText = anchorLabels[anchor.identifier] else {
            fatalError("Missing Expected Associated Label For Anchor")
        }
        let label = TemplateLabelNode(text: labelText)
        node.addChild(label)
    }
    
   
    
    private func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.restartSession()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
}

extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}

extension UIImage {
    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContext(newSize);
        let context = UIGraphicsGetCurrentContext()!
        
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
extension Array {
    /// Returns an array containing this sequence shuffled
    var shuffled: Array {
        var elements = self
        return elements.shuffle()
    }
    /// Shuffles this sequence in place
    @discardableResult
    mutating func shuffle() -> Array {
        let count = self.count
        indices.lazy.dropLast().forEach {
            swapAt($0, Int(arc4random_uniform(UInt32(count - $0))) + $0)
        }
        return self
    }
    var chooseOne: Element { return self[Int(arc4random_uniform(UInt32(count)))] }
    func choose(_ n: Int) -> Array { return Array(shuffled.prefix(n)) }
}
