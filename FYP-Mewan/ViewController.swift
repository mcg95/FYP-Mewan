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

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, UIGestureRecognizerDelegate {
    
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


        }

    }
    @IBOutlet weak var flashToggleButton: UIButton!
    
    @IBOutlet weak var countdownLabel: SRCountdownTimer!
    
    @IBAction func switchValueDidChange(sender: DGRunkeeperSwitch!) {
        selectedButtonIndex = sender.selectedIndex
        print("valueChanged: \(sender.selectedIndex)")
    }
    
    // The pixel buffer being held for analysis; used to serialize Vision requests.
    private var currentBuffer: CVPixelBuffer?
    
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
    
    //SwiftMessages Variables
    var swiftMsgView: MessageView? = nil
    
    
    //CoreData Model Array
    var learntWords = [LearntWords]()
    
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
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
            //answerOne.isHidden = true
      //  answerTwo.isHidden = true
       // answerThree.isHidden = true

        // Load the SKScene from 'Scene.sks'
        statusViewController.restartExperienceHandler = { [unowned self] in self.restartSession()}
        
        let runkeeperSwitch2 = DGRunkeeperSwitch()
        runkeeperSwitch2.titles = ["Text", "Objects"]
        runkeeperSwitch2.backgroundColor = UIColor(red: 239.0/255.0, green: 95.0/255.0, blue: 49.0/255.0, alpha: 1.0)
        runkeeperSwitch2.selectedBackgroundColor = .white
        runkeeperSwitch2.titleColor = .white
        runkeeperSwitch2.selectedTitleColor = UIColor(red: 239.0/255.0, green: 95.0/255.0, blue: 49.0/255.0, alpha: 1.0)
        runkeeperSwitch2.titleFont = UIFont(name: "HelveticaNeue-Medium", size: 13.0)
        runkeeperSwitch2.frame = CGRect(x: 50.0, y: 20.0, width: view.bounds.width - 100.0, height: 30.0)
        runkeeperSwitch2.autoresizingMask = [.flexibleWidth] // This is needed if you want the control to resize
        view.addSubview(runkeeperSwitch2)
        
        runkeeperSwitch2.addTarget(self, action: #selector(ViewController.switchValueDidChange(sender:)), for: .valueChanged )
        countdownLabel.isHidden = true
        flashImage.image = #imageLiteral(resourceName: "flashOff")

        guard let objectModel = try? VNCoreMLModel(for: Inceptionv3().model) else {
            fatalError("can't load Object model")
        }
        let fetchRequest:NSFetchRequest<LearntWords> = LearntWords.fetchRequest()
        
        do{
            let lWords = try CoreDataService.context.fetch(fetchRequest)
            self.learntWords = lWords
        }
        catch{
            print("CoreDataService Fetch Request Failed")
        }
    }
    
    private func restartSession(){
        //   anchorLabels = [UUID: String]()
        //statusViewController.cancelAllScheduledMessages()
        sceneView.delegate?.sessionInterruptionEnded!(sceneView.session)
        let configuration = ARWorldTrackingConfiguration()
        
        
        
        //statusViewController.showMessage("RESTARTING SESSION")
    }
    
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard currentBuffer == nil, case .normal = frame.camera.trackingState else{
            return
        }
        visionQueue.async {
            do{
                // Release the pixel buffer when done, allowing the next buffer to be processed.
                defer { self.currentBuffer = nil }
                self.currentBuffer = frame.capturedImage
                self.convertPixelBuffer(cvPixelBuffer: self.currentBuffer!)
                //try requestHandler.perform([self.classificationRequest])
                
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
            self.detectText(image: uiImage!)}
        else if selectedButtonIndex == 1{
            if shouldProcessFrames == true{
                 DispatchQueue.main.async {
                    self.imagePreview.isHidden = true
                    
                }
                setupVision()
                
                
            } else if shouldProcessFrames == false{
                if ranFunctionTimer == false {
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
                }
                
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
                                    let processedImage = preProcess(image: croppedImage)
                                    self.classificationRequest(image: processedImage,
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
        
        // Instantiate the model from its generated Swift class.
        let model = try? VNCoreMLModel(for: Alphanum_28x28().model)
        let request = VNCoreMLRequest(model: model!) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation],
                let topResult = results.first(where: {result in result.confidence > 0.5}) else {
                    // fatalError("Unexpected result type from VNCoreMLRequest")
                    self?.identifierString = ""
                    return            }
            let result = topResult.identifier
            let classificationInfo: [String: Any] = ["wordNumber" : wordNumber,
                                                     "characterNumber" : characterNumber,
                                                     "class" : result]
            self?.totConfidence += topResult.confidence
            let totConfidenceDouble = Double((self?.totConfidence)!)
            let resultsCount = Double(results.count)
            let avgConfidence = totConfidenceDouble/resultsCount
            let averageConfidence = Double(avgConfidence)
            if (averageConfidence > (self?.confidenceThreshold)!){
                self?.shouldProcessFrames = false
                print("Stopped Processing Frames")
                self?.handleResult(classificationInfo)
                
                
            }else{
                self?.handleResult(classificationInfo)
            }
            
        }
        guard let ciImage = CIImage(image: image) else {
            fatalError("Could not convert UIImage to CIImage :(")
        }
        // Crop input images to square area at center, matching the way the ML model was trained.
        request.imageCropAndScaleOption = .centerCrop
        
        // Use CPU for Vision processing to ensure that there are adequate GPU resources for rendering.
        request.usesCPUOnly = true
        let orientation = CGImagePropertyOrientation(UIDevice.current.orientation)
        
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
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
        /*    let misspelledRange = textChecker.rangeOfMisspelledWord(in: word(fromDictionary: textMetadata[sortedKey]!), range: NSRange(0..<word(fromDictionary: textMetadata[sortedKey]!).utf16.count), startingAt: 0, wrap: false, language: "en_US")
         if misspelledRange.location != NSNotFound,
         let guesses = textChecker.guesses(forWordRange: misspelledRange, in: word(fromDictionary: textMetadata[sortedKey]!), language: "en_US") {
         correctStr = guesses.first!
         print("Final Result: " + word(fromDictionary: textMetadata[sortedKey]!))
         statusViewController.showMessage(correctStr)
         print("Corrected Result: " + correctStr)
         
         }*/
        print("here is the result" + result)
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
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        
        guard let results = request.results as? [VNClassificationObservation],
            let topResult = results.first(where: {result in result.confidence > 0.75}) else {
                // fatalError("Unexpected result type from VNCoreMLRequest")
                self.identifierString = ""
                return            }
        
        let classificationInfo: [String: Any] = ["wordNumber" : topResult.identifier,
                                                 "characterNumber" : String(format:" : %.2f", topResult.confidence)]
        // Get Classification
        
        let result = topResult.identifier
        
        /*  self.totConfidence += topResult.confidence
         let totConfidenceDouble = Double((self.totConfidence))
         let resultsCount = Double(result.count)
         let avgConfidence = totConfidenceDouble/resultsCount
         let averageConfidence = Double(avgConfidence)
         if (averageConfidence > (self.objectConfidenceThreshold)){
         self.shouldProcessFrames = false
         print("Stopped Processing Frames")*/
        
        DispatchQueue.main.async {
            
            // Print Classifications
            print(topResult.identifier)
            self.englishWord = topResult.identifier
            self.translateText(text2Translate: topResult.identifier)
            // print("-------------")
            
            
            // self.statusViewController.showMessage()
            
        }
        // }
        
        
        // Render Classifications
        
    }
    
    func translateText(text2Translate: String){
        
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
        
        malayWord = langTranslations![0].translations[numberOfTranslations].text
        
        let wordModel = LearntWords(context: CoreDataService.context)
        let englishWordsArr = self.englishWord.components(separatedBy: ", ")
        let malayWordsArr = malayWord.components(separatedBy: ",")
        wordModel.englishword = englishWordsArr[0]
        wordModel.malayword = malayWordsArr[0]
        let detectedWord = learntWords.filter{ $0.englishword == wordModel.englishword }
        
        let wordExists = detectedWord.isEmpty
        if wordExists == false{
            
            self.shouldProcessFrames = false
            
            if displayedAnswers == false{
                
                displayedAnswers = true
                displayAnswers()
            }
         /*   print("Show user 3 answers to choose the correct one from....FALSE")
            //Config view
            self.swiftMsgView = MessageView.viewFromNib(layout: .cardView)
            self.swiftMsgView?.configureContent(title: "False!", body: "Show user 3 answers to choose the correct one from.")
            let iconText = "✅"
            self.swiftMsgView?.configureTheme(backgroundColor: UIColor.init(red: 0/255.0, green: 204.0/255.0, blue: 102.0/255.0, alpha: 0.8), foregroundColor: UIColor.white, iconImage: nil, iconText: iconText)
            // self.swiftMsgView?.button?.setImage(Icon.errorSubtle.image, for: .normal)
            self.swiftMsgView?.button?.setTitle("Hide", for: .normal)
            self.swiftMsgView?.button?.backgroundColor = UIColor.clear
            self.swiftMsgView?.button?.tintColor = UIColor.white
            self.swiftMsgView?.configureDropShadow()
            
            //Config
            var swiftConfig = SwiftMessages.defaultConfig
            swiftConfig.interactiveHide = true
            swiftConfig.presentationStyle = .top
            swiftConfig.duration = .automatic
            
            //Show
            SwiftMessages.show(config: swiftConfig, view: self.swiftMsgView!)
            */
        }else if wordExists == true{
            self.shouldProcessFrames = false
            
            
            //Config view
            self.swiftMsgView = MessageView.viewFromNib(layout: .cardView)
            self.swiftMsgView?.configureContent(title: "True!", body: "This is a new word, so proceed with saving it into CoreData.")
            let iconText = "✅"
            self.swiftMsgView?.configureTheme(backgroundColor: UIColor.init(red: 0/255.0, green: 204.0/255.0, blue: 102.0/255.0, alpha: 0.8), foregroundColor: UIColor.white, iconImage: nil, iconText: iconText)
            // self.swiftMsgView?.button?.setImage(Icon.errorSubtle.image, for: .normal)
            self.swiftMsgView?.button?.setTitle("Hide", for: .normal)
            self.swiftMsgView?.button?.backgroundColor = UIColor.clear
            self.swiftMsgView?.button?.tintColor = UIColor.white
            self.swiftMsgView?.configureDropShadow()
            
            //Config
            var swiftConfig = SwiftMessages.defaultConfig
            swiftConfig.interactiveHide = true
            swiftConfig.presentationStyle = .top
            swiftConfig.duration = .automatic
            
            //Show
            SwiftMessages.show(config: swiftConfig, view: self.swiftMsgView!)
            print("This is a new word, so proceed with saving it into CoreData....TRUE")
         //   print("These are the Core Data words on top " + self.learntWords[0].englishword! + self.learntWords[0].malayword!)
            
            
            self.learntWords.append(wordModel)
            
            self.saveToCoreData()
        
        }
    
        //-------------------------------Need to check CoreData for recognized object, if it exists, display options to choose correct answer, else add the word to CoreData and display translation.------------------------------
      
        
        //----------------------------------------------------------------------------------------//
    }
    
 
    func saveToCoreData(){
       
        CoreDataService.saveContext()
        DispatchQueue.main.async {
            self.statusViewController.showMessage("Malay:" + self.malayWord + " English: " + self.englishWord)
        }
    }
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // HIT TEST : REAL WORLD
        // Get Screen Centre
        let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
        
        let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint]) // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points.
        
        if let closestResult = arHitTestResults.first {
            // Get Coordinates of HitTest
            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            // Create 3D Text
            let node : SCNNode = createNewBubbleParentNode(englishWord)
            sceneView.scene.rootNode.addChildNode(node)
            node.position = worldCoord
        }
    }
    
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
    
    func displayAnswers(){
        var randomWords1 = ["1","2","3","4","5"]
        var randomWords2 = ["6","7","8","9","10"]
        let shuffledRandomWords1 = randomWords1.shuffle()
        let shuffledRandomWords2 = randomWords2.shuffle()
        let malayWordArray = malayWord.components(separatedBy: ", ")
        let trimmedMalayWord = malayWordArray[0]
        let correctAnswer = "\(trimmedMalayWord)"
        var answerList:[String] = ["\(correctAnswer)","\(shuffledRandomWords1.chooseOne)","\(shuffledRandomWords2.chooseOne)"]
        var shuffledAnswerList = answerList.shuffle()
            DispatchQueue.main.async {
               

                
               // i.setTitle(answerList.sm_random(), for: .normal)
                self.displayedAnswers = false
                self.answerOne.setTitle(answerList[0], for: .normal)
                self.answerTwo.setTitle(answerList[1], for: .normal)
                self.answerThree.setTitle(answerList[2], for: .normal)
                self.answerOne.isHidden = false
                self.answerTwo.isHidden = false
                self.answerThree.isHidden = false
                
        }
      
        
       
        
    }
    // MARK: - ARSKViewDelegate
    
    func view(_ view: ARSKView, nodeFor anchor: ARAnchor) -> SKNode? {
        // Create and configure a node for the anchor added to the view's session.
        let labelNode = SKLabelNode(text: "👾")
        labelNode.horizontalAlignmentMode = .center
        labelNode.verticalAlignmentMode = .center
        return labelNode;
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
   /*
    
    @IBAction func placeLabelAtLocation(sender: UITapGestureRecognizer){
        let hitLocationInView = sender.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(hitLocationInView, types: [.featurePoint, .estimatedHorizontalPlane])
        if let result = hitTestResults.first {
            
            // Add a new anchor at the tap location.
            let anchor = ARAnchor(transform: result.worldTransform)
            sceneView.session.add(anchor: anchor)
            
            // Track anchor ID to associate text with the anchor after ARKit creates a corresponding SKNode.
            anchorLabels[anchor.identifier] = identifierString
        }
    }
    */
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
