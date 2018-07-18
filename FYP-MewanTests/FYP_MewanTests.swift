//
//  FYP_MewanTests.swift
//  FYP-MewanTests
//
//  Created by Mewan Chathuranga on 02/05/2018.
//  Copyright © 2018 Mewan Chathuranga. All rights reserved.
//

import XCTest
import Vision
import ARKit
import GPUImage2
import CoreData

@testable import FYP_Mewan

class FYP_MewanTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    var learntWords = [LearntWords]()
    func testAddingToCoreData(){
        fetchLearntWordsCoreData()
        let promise = expectation(description: "TestWord1")
        let wordToAdd = "TestWord1"
        let wordModel = LearntWords(context: CoreDataService.context)
        let detectedWord = learntWords.filter{ $0.englishword == wordToAdd }
        let wordExists = detectedWord.isEmpty
        if wordExists == false{
            print("Word Exists! Try a new word.")
        }else{
            
            wordModel.englishword = wordToAdd
            wordModel.malayword = wordToAdd
            print("Word added to CoreData.")
            learntWords.append(wordModel)
            CoreDataService.saveContext()
            
            fetchLearntWordsCoreData()
            for word in learntWords{
                if word.englishword == wordToAdd{
                    print(word.englishword)
                    promise.fulfill()

                }
            }

        }
        
        waitForExpectations(timeout: 4, handler: nil)
    }
    
    func testLoadingFromCoreData(){
        fetchLearntWordsCoreData()
        let promise = expectation(description: "iPod")
        let detectedWord = learntWords.filter{ $0.englishword == "iPod" }
        let wordExists = detectedWord.isEmpty
        if wordExists == false{
            
            for word in learntWords{
                if word.englishword == "iPod"{
                    promise.fulfill()
                }
            }
            
        }
       
        waitForExpectations(timeout: 4, handler: nil)
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
    
    var textMetadata = [Int: [Int: String]]()
    var currentDetectedWord:String?

    func testDetectedText(){
        let promise = expectation(description: "large")
        let toProcessImg =  #imageLiteral(resourceName: "Test4")
        let luminanceFilter = LuminanceThreshold()
        luminanceFilter.threshold = 0.5
        let filteredImg = toProcessImg.filterWithOperation(luminanceFilter)
        let filteredImgFinal = filteredImg.rotate(radians: .pi/2)
        //AdaptiveThreshold
        let handler = VNImageRequestHandler(cgImage: filteredImg.cgImage!)
      
            let request: VNDetectTextRectanglesRequest =
                VNDetectTextRectanglesRequest(completionHandler: { [unowned self] (request, error) in
                    if (error != nil) {
                        print("Got Error In Run Text Dectect Request :(")
                    } else {
                        guard let results = request.results as? Array<VNTextObservation> else {
                            fatalError("Unexpected result type from VNDetectTextRectanglesRequest")
                        }
                     /*   if (results.count == 0) {
                            self.handleEmptyResults()
                            return
                        }*/
                        var numberOfWords = 0
                        for textObservation in results {
                            var numberOfCharacters = 0
                            for rectangleObservation in textObservation.characterBoxes! {
                                let croppedImage = crop(image: #imageLiteral(resourceName: "Test"), rectangle: rectangleObservation)
                                if let croppedImage = croppedImage {
                                    
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
            
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
            print(self.currentDetectedWord)
            
            if self.currentDetectedWord == "large"{
                promise.fulfill()
            }
        })
        
        
        
        waitForExpectations(timeout: 6, handler: nil)
      
    }
    
    private func classificationRequest(image: UIImage, wordNumber: Int, characterNumber: Int){
        
       //let luminanceFilter = LuminanceThreshold()
       //luminanceFilter.threshold = 0.5
        let processedImg = image
            //.filterWithOperation(luminanceFilter)
        // Instantiate the model from its generated Swift class.
      
        let model = try? VNCoreMLModel(for: OCR().model)
        let request = VNCoreMLRequest(model: model!) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation],
                let topResult = results.first(where: {result in result.confidence > 0.9}) else {
                    // fatalError("Unexpected result type from VNCoreMLRequest")
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
        
        
        
    }
    private func displayClassifierResults() {
        var result: String = ""
        if (textMetadata.isEmpty) {
            let errMsg = "The image does not contain any text."
            return
        }
        let sortedKeys = textMetadata.keys.sorted()
        
        for sortedKey in sortedKeys {
            result +=  word(fromDictionary: textMetadata[sortedKey]!) + " "
            currentDetectedWord = result

        }
        
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
    
    var detectedObject:String?
    func testObjectIdentification(){
        
        let promise = expectation(description: "iPod")
        let uIImage = #imageLiteral(resourceName: "ipod")

        var visionRequests = [VNRequest]()

        let model = try? VNCoreMLModel(for: Inceptionv3().model)
        let classificationRequest = VNCoreMLRequest(model: model! , completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
        visionRequests = [classificationRequest]
        
        let rotatedImgFinal = uIImage.rotate(radians: .pi/2)
        
        
        
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage:CIImage(image: #imageLiteral(resourceName: "ipod"))!, options: [:])
        
        // Run Vision Image Request
        do {
            try imageRequestHandler.perform(visionRequests)
            
        } catch {
            print(error)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
            print(self.detectedObject)
            
            if self.detectedObject == "iPod"{
                promise.fulfill()
            }
        })
        
        
        
        waitForExpectations(timeout: 6, handler: nil)
        
        
    }
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
                   // self.identifierString = ""
                    return            }
            
            let classificationInfo: [String: Any] = ["wordNumber" : topResult.identifier,
                                                     "characterNumber" : String(format:" : %.2f", topResult.confidence)]
            // Get Classification
            
            result = topResult.identifier
            let englishWordArray = result.components(separatedBy: ", ")
            let trimmedEnglishWord = englishWordArray[0]
            self.detectedObject = trimmedEnglishWord
            print("Classification Completion:", result)
        }
    }
        
    var translationResult: String?
    var translationComplete = false
    func testTranslation() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        let textToTranslate = "exit"
        let promise = expectation(description: "Keluar")
        translateTextToMalay(text2Translate: textToTranslate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: {
            print(self.translationResult)
            
            if self.translationResult == "Keluar"{
                promise.fulfill()
            }
        })
        
            
        
        waitForExpectations(timeout: 7, handler: nil)

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
        let translatedWord = langTranslations![0].translations[numberOfTranslations].text
        //.components(separatedBy: ", ")
        
        translationResult = translatedWord
        translationComplete = true
        

        
        
        
        
        
    }
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
