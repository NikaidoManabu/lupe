import UIKit
import AVFoundation

class ViewController: UIViewController , UIGestureRecognizerDelegate , UIScrollViewDelegate , G8TesseractDelegate ,AVCaptureVideoDataOutputSampleBufferDelegate{
    
    
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var myButton: UIButton!
    @IBOutlet weak var mySlider: UISlider!
    @IBOutlet weak var maxZoomLabel: UILabel!
    @IBOutlet weak var minZoomLabel: UILabel!
    @IBOutlet weak var myScrollView: UIScrollView!
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var cameraImageView: UIImageView!
    @IBOutlet weak var analyzeImageView: UIImageView!
    @IBOutlet weak var analyzeButton: UIButton!
    @IBOutlet weak var ActivityIndicatorView: UIActivityIndicatorView!
    
    // セッション.
    var mySession : AVCaptureSession!
    // デバイス.
    var myDevice : AVCaptureDevice!
    // 画像のアウトプット.
    var input:AVCaptureDeviceInput!
    var output:AVCaptureVideoDataOutput!
    
    //画面モード
    var mode = "Dynamic"
    
    //スライダーによる最大拡大
    let maxZoom : Float = 20
    
//    let myVideoLayer =
    override func viewDidLoad() {
        super.viewDidLoad()
        
        changeMode(mode: "Dynamic")
        
        maxZoomLabel.text = "x"+String(maxZoom)
        mySlider.value = 0
        
        // 画面タップでピントをあわせる
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.tappedScreen(gestureRecognizer:)))
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(ViewController.pinchedGesture(gestureRecgnizer:)))
        // デリゲートをセット
        tapGesture.delegate = self
        // Viewにタップのジェスチャーを追加
        self.view.addGestureRecognizer(tapGesture)
        self.view.addGestureRecognizer(pinchGesture)

        
        // スクロールビューの設定
        self.myScrollView.delegate = self
        self.myScrollView.minimumZoomScale = 1
        self.myScrollView.maximumZoomScale = 8
        self.myScrollView.isScrollEnabled = true
        self.myScrollView.showsHorizontalScrollIndicator = true
        self.myScrollView.showsVerticalScrollIndicator = true
        
        let doubleTapGesture: UITapGestureRecognizer = UITapGestureRecognizer(target: self
            , action: #selector(ViewController.doubleTap(gesture:)))
        doubleTapGesture.numberOfTapsRequired = 2
        self.StaticImageView.isUserInteractionEnabled = true
        self.StaticImageView.addGestureRecognizer(doubleTapGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // カメラの設定
        setupCamera()
    }
    
    // メモリ解放
    override func viewDidDisappear(_ animated: Bool) {
        // camera stop メモリ解放
        mySession.stopRunning()
        
        for output in mySession.outputs {
            mySession.removeOutput(output as? AVCaptureOutput)
        }
        
        for input in mySession.inputs {
            mySession.removeInput(input as? AVCaptureInput)
        }
        mySession = nil
        myDevice = nil
    }
    
    func setupCamera(){
        // AVCaptureSession: キャプチャに関する入力と出力の管理
        mySession = AVCaptureSession()
        
        // sessionPreset: キャプチャ・クオリティの設定
        mySession.sessionPreset = AVCaptureSessionPresetHigh
        
        
        // デバイス一覧の取得.
        let devices = AVCaptureDevice.devices()

        // バックカメラをmyDeviceに格納.
        for device in devices! {
            if((device as AnyObject).position == AVCaptureDevicePosition.back){
                myDevice = device as! AVCaptureDevice
            }
        }
        
        // カメラからの入力データ
        do {
            input = try AVCaptureDeviceInput(device: myDevice) as AVCaptureDeviceInput
        } catch let error as NSError {
            print(error)
        }
        
        // 入力をセッションに追加
        if(mySession.canAddInput(input)) {
            mySession.addInput(input)
        }
        
        // AVCaptureVideoDataOutput:動画フレームデータを出力に設定
        output = AVCaptureVideoDataOutput()
        
        // 出力をセッションに追加
        if(mySession.canAddOutput(output)) {
            mySession.addOutput(output)
        }
        
        // ピクセルフォーマットを 32bit BGR + A とする
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)]
        
        // フレームをキャプチャするためのサブスレッド用のシリアルキューを用意
        output.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        
        output.alwaysDiscardsLateVideoFrames = true
        
        mySession.startRunning()
        
        // deviceをロックして設定
        do {
            try myDevice.lockForConfiguration()
            // フレームレート
            myDevice.activeVideoMinFrameDuration = CMTimeMake(1, 30)
            myDevice.unlockForConfiguration()
        } catch _ {
        }
    }

    
    @IBAction func cameraButton(_ sender: Any) {
        onClickMyButton(sender: sender as! UIButton)
    }
    
    
    // ボタンイベント.
    func onClickMyButton(sender: UIButton){
        if(mode == "Dynamic"){
            changeMode(mode: "Static")
            
            //imageViewを作ってaddSubviewする
            let myImage = self.image.image
            let staticimageView = self.makeImageView()
            staticimageView.image = myImage
            self.myScrollView.addSubview(staticimageView)
            
        }else if(mode == "Static" || mode=="Analyze"){
            changeMode(mode: "Dynamic")
            StaticImageView.removeFromSuperview()
            
        }
    }
    
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        print("captureOutput")
        // キャプチャしたsampleBufferからUIImageを作成
        let image:UIImage = self.captureImage(sampleBuffer: sampleBuffer)
        
        // カメラの画像を画面に表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.image.image = image
        }
    }
    func captureImage(sampleBuffer:CMSampleBuffer) -> UIImage{
        
        // Sampling Bufferから画像を取得
        let imageBuffer:CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        // pixel buffer のベースアドレスをロック
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let baseAddress:UnsafeMutableRawPointer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
        
        let bytesPerRow:Int = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width:Int = CVPixelBufferGetWidth(imageBuffer)
        let height:Int = CVPixelBufferGetHeight(imageBuffer)
        
        // 色空間
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let newContext:CGContext = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace,  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue)!
        
        let imageRef:CGImage = newContext.makeImage()!
        let resultImage = UIImage(cgImage: imageRef, scale: 1.0, orientation: UIImageOrientation.right)
        
        return resultImage
    }
    
    func changeMode(mode: String){
        switch mode {
        case "Dynamic":
            self.mode="Dynamic"
//            myButton.backgroundColor = UIColor.green
            cameraImageView.image=UIImage(named: "Screenshot.png")!
            image.isHidden=false
            mySlider.isHidden=false
            maxZoomLabel.isHidden=false
            minZoomLabel.isHidden=false
            myScrollView.isHidden=true
            myScrollView.zoomScale=1.0
//            StaticImageView.isHidden=true
            analyzeImageView.isHidden=true
            analyzeButton.isHidden=true
            textLabel.isHidden=true
//            print("zoomScale \(myScrollView.zoomScale)")
            break
        case "Static":
            self.mode="Static"
//            myButton.backgroundColor = UIColor.blue
            cameraImageView.image=UIImage(named: "Video Call.png")!
            image.isHidden=true
            mySlider.isHidden=true
            maxZoomLabel.isHidden=true
            minZoomLabel.isHidden=true
            myScrollView.isHidden=false
            myScrollView.zoomScale=1.0
//            StaticImageView.isHidden=false
            analyzeImageView.isHidden=false
            analyzeImageView.image=UIImage(named: "Handwritten OCR.png")!
            analyzeButton.isHidden=false
            textLabel.isHidden=true
//            ScreenShotImageView.removeFromSuperview()
//            print("zoomScale \(myScrollView.zoomScale)")
            break
        case "Analyze":
            self.mode="Analyze"
//            myButton.backgroundColor = UIColor.blue
            cameraImageView.image=UIImage(named: "Video Call.png")!
            image.isHidden=true
            mySlider.isHidden=true
            maxZoomLabel.isHidden=true
            minZoomLabel.isHidden=true
            myScrollView.isHidden=false
            analyzeImageView.isHidden=false
            analyzeImageView.image=UIImage(named: "Cancel.png")!
            analyzeButton.isHidden=false
            textLabel.isHidden=false
            textLabel.text=""
//            print("zoomScale \(myScrollView.zoomScale)")
            break
        default:
            break
        }
    }
    
    //view生成
    let StaticImageView = UIImageView()
    func makeImageView() -> UIImageView{
        StaticImageView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        return StaticImageView
    }
    
    @IBAction func sliderChanged(_ sender: UISlider) {
        //倍率変更
        //線形だと値が大きいときのズームの変わり具合が（スライダーの移動距離に対して）少なく感じる
        let maxZoomInDevixe = Float(myDevice.activeFormat.videoMaxZoomFactor)
        //        print(myDevice.activeFormat.videoMaxZoomFactor)//95.625
//        var zoom = sender.value * maxZoom
        var zoom = pow(maxZoom,sender.value)
        if(zoom > maxZoomInDevixe - 0.1){zoom = maxZoomInDevixe - 0.1}
        if(zoom < 1.0){zoom = 1.0}
        do {
            try myDevice.lockForConfiguration()
//            myDevice.ramp(toVideoZoomFactor: CGFloat(zoom), withRate: 100000.0)
            myDevice.videoZoomFactor = CGFloat(zoom)
            myDevice.unlockForConfiguration()
            oldZoomScale = CGFloat(zoom)
        } catch {
            
        }
    }
    
    func focusWithMode(focusMode : AVCaptureFocusMode, exposeWithMode expusureMode :AVCaptureExposureMode, atDevicePoint point:CGPoint, motiorSubjectAreaChange monitorSubjectAreaChange:Bool) {
        
            let device : AVCaptureDevice = myDevice
            
            do {
                try device.lockForConfiguration()
                if(device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode)){
                    device.focusPointOfInterest = point
                    device.focusMode = focusMode
                }
                if(device.isExposurePointOfInterestSupported && device.isExposureModeSupported(expusureMode)){
                    device.exposurePointOfInterest = point
                    device.exposureMode = expusureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
                
            } catch let error as NSError {
                print(error.debugDescription)
            }
    }
    
    let focusView = UIView()
    func tappedScreen(gestureRecognizer: UITapGestureRecognizer) {
        print("タップしました")
        if(mode=="Dynamic"){
            let tapCGPoint = gestureRecognizer.location(ofTouch: 0, in: gestureRecognizer.view)
            focusView.frame.size = CGSize(width: 120, height: 120)
            focusView.center = tapCGPoint
            focusView.backgroundColor = UIColor.white.withAlphaComponent(0)
            focusView.layer.borderColor = UIColor.white.cgColor
            focusView.layer.borderWidth = 2
            focusView.alpha = 1
            image.addSubview(focusView)
        
            UIView.animate(withDuration: 0.5, animations: {
                self.focusView.frame.size = CGSize(width: 80, height: 80)
                self.focusView.center = tapCGPoint
            }, completion: { Void in
                UIView.animate(withDuration: 0.5, animations: {
                    self.focusView.alpha = 0
                })
            })
        
            self.focusWithMode(focusMode: AVCaptureFocusMode.autoFocus, exposeWithMode: AVCaptureExposureMode.autoExpose, atDevicePoint: tapCGPoint, motiorSubjectAreaChange: true)
        }
    }
    
    var oldZoomScale: CGFloat = 1.0
    func pinchedGesture(gestureRecgnizer: UIPinchGestureRecognizer) {
        print("ピンチ：view")
        if(mode=="Dynamic"){//ズーム
            do {
                try myDevice.lockForConfiguration()
                // ズームの最大値
                let maxZoomScale: CGFloat = CGFloat(self.maxZoom)
                // ズームの最小値
                let minZoomScale: CGFloat = 1.0
                // 現在のカメラのズーム度
                var currentZoomScale: CGFloat = myDevice.videoZoomFactor
                // ピンチの度合い
                let pinchZoomScale: CGFloat = gestureRecgnizer.scale
                
                // ピンチアウトの時、前回のズームに今回のズーム-1を指定
                // 例: 前回3.0, 今回1.2のとき、currentZoomScale=3.2
                if pinchZoomScale > 1.0 {
                    currentZoomScale = oldZoomScale+pinchZoomScale-1
                } else {
                    currentZoomScale = oldZoomScale-(1-pinchZoomScale)*oldZoomScale
                }
                
                // 最小値より小さく、最大値より大きくならないようにする
                if currentZoomScale < minZoomScale {
                    currentZoomScale = minZoomScale
                }
                else if currentZoomScale > maxZoomScale {
                    currentZoomScale = maxZoomScale
                }
                
                // 画面から指が離れたとき、stateがEndedになる。
                if gestureRecgnizer.state == .ended {
                    oldZoomScale = currentZoomScale
                }
                
                myDevice.videoZoomFactor = currentZoomScale
                myDevice.unlockForConfiguration()
                
                self.mySlider.value=Float(log(myDevice.videoZoomFactor)/log(20))
            } catch {
                // handle error
                return
            }
        }
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        print("ピンチ：scrollView")
//        if(mode=="Dynamic"){
//            return self.StaticImageView
//        }else{//if(mode=="Static"){
            return self.StaticImageView
//        }
    }
    
    // ダブルタップ
    func doubleTap(gesture: UITapGestureRecognizer) -> Void {
//        print(self.myScrollView.zoomScale)
        if (self.myScrollView.zoomScale < self.myScrollView.maximumZoomScale) {
            let newScale = self.myScrollView.zoomScale * 3
            let zoomRect = self.zoomRectForScale(scale: newScale, center: gesture.location(in: gesture.view))
            self.myScrollView.zoom(to: zoomRect, animated: true)
        } else {
            self.myScrollView.setZoomScale(1.0, animated: true)
        }
    }
    
    func zoomRectForScale(scale:CGFloat, center: CGPoint) -> CGRect{
        let size = CGSize(
            width: self.myScrollView.frame.size.width / scale,
            height: self.myScrollView.frame.size.height / scale
        )
        return CGRect(
            origin: CGPoint(
                x: center.x - size.width / 2.0,
                y: center.y - size.height / 2.0
            ),
            size: size
        )
    }
    
    func analyze() {
        //解析用画像用意
        let tesseract = G8Tesseract(language: "jpn")
        tesseract?.delegate = self
        tesseract?.image = myTrim()
        tesseract?.recognize()
        
        ActivityIndicatorView.stopAnimating()
        self.textLabel.text = tesseract?.recognizedText
//        print(tesseract?.recognizedText)
    }

    func myTrim() -> UIImage{
        let srcImage : UIImage = self.StaticImageView.image! /* UIImagePickerなどから取得したUIImage */
        let factor = srcImage.size.width / self.view.frame.width;
        let scale = 1 / self.myScrollView.zoomScale;
        let x = self.myScrollView.contentOffset.x * scale * factor;
        let y = self.myScrollView.contentOffset.y * scale * factor;
        let width = myScrollView.bounds.width * scale * factor;
        let height = myScrollView.bounds.height * scale * factor;
        
//        print("\(factor) \(scale)")
//        let fsf = self.myScrollView.frame//0
//        let fsb = self.myScrollView.bounds//716,1273
//        let fif = self.StaticImageView.frame//0
//        let fib = self.StaticImageView.bounds//0
//        let fsco = self.myScrollView.contentOffset//716,1273
        
        let cropArea = CGRect(x: x,
                              y: y,
                              width: width,
                              height: height)
        let cropping = srcImage.cropping(to: cropArea) //コード最下行で定義
        return cropping!
    }
    
    @IBAction func tapAnalyzeButton(_ sender: Any) {
        if(mode=="Static"){
            ActivityIndicatorView.startAnimating()
            changeMode(mode: "Analyze")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.analyze()
                self.ActivityIndicatorView.stopAnimating()
                
            }
        }else if(mode=="Analyze"){
            changeMode(mode: "Static")
        }
        
    }
}

extension UIImage {
    func cropping(to: CGRect) -> UIImage? {
        var opaque = false
        if let cgImage = cgImage {
            switch cgImage.alphaInfo {
            case .noneSkipLast, .noneSkipFirst:
                opaque = true
            default:
                break
            }
        }
        UIGraphicsBeginImageContextWithOptions(to.size, opaque, scale)
        draw(at: CGPoint(x: -to.origin.x, y: -to.origin.y))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}

