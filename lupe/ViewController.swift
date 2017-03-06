import UIKit
import AVFoundation

class ViewController: UIViewController , UIGestureRecognizerDelegate{
    
    
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var myButton: UIButton!
    @IBOutlet weak var mySlider: UISlider!
    @IBOutlet weak var maxZoomLabel: UILabel!
    
    // セッション.
    var mySession : AVCaptureSession!
    // デバイス.
    var myDevice : AVCaptureDevice!
    // 画像のアウトプット.
    var myImageOutput: AVCaptureStillImageOutput!
    
    //画面モード
    var mode = "Dynamic"
    
    //スライダーによる最大拡大
    let maxZoom : Float = 20
    
//    let myVideoLayer =
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        maxZoomLabel.text = "x"+String(maxZoom)
        mySlider.value = 0
        
        // セッションの作成.
        mySession = AVCaptureSession()
        
        // デバイス一覧の取得.
        let devices = AVCaptureDevice.devices()
        
        // バックカメラをmyDeviceに格納.
        for device in devices! {
            if((device as AnyObject).position == AVCaptureDevicePosition.back){
                myDevice = device as! AVCaptureDevice
            }
        }
        
        // バックカメラからVideoInputを取得.
        let videoInput = try! AVCaptureDeviceInput.init(device: myDevice)
        // セッションに追加.
        mySession.addInput(videoInput)
        
        // 出力先を生成.
        myImageOutput = AVCaptureStillImageOutput()
        
        // セッションに追加.
        mySession.addOutput(myImageOutput)
        
        // 画像を表示するレイヤーを生成.
        let myVideoLayer = AVCaptureVideoPreviewLayer.init(session: mySession)
        myVideoLayer?.frame = self.view.bounds
        myVideoLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        // Viewに追加.
        self.image.layer.addSublayer(myVideoLayer!)
        
        // セッション開始.
        mySession.startRunning()
        
        
        
        // 画面タップでピントをあわせる
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.tappedScreen(gestureRecognizer:)))
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(ViewController.pinchedGesture(gestureRecgnizer:)))
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(ViewController.swipedGesture(gestureRecgnizer:)))
        // デリゲートをセット
        tapGesture.delegate = self
        // Viewにタップのジェスチャーを追加
        self.view.addGestureRecognizer(tapGesture)
        self.view.addGestureRecognizer(pinchGesture)
        self.view.addGestureRecognizer(swipeGesture)

    }
    
    @IBAction func cameraButton(_ sender: Any) {
        onClickMyButton(sender: sender as! UIButton)
    }
    
    
    // ボタンイベント.
    func onClickMyButton(sender: UIButton){
        if(mode == "Dynamic"){
        // ビデオ出力に接続.
        // let myVideoConnection = myImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        let myVideoConnection = myImageOutput.connection(withMediaType: AVMediaTypeVideo)
        
        // 接続から画像を取得.
        self.myImageOutput.captureStillImageAsynchronously(from: myVideoConnection, completionHandler: {(imageDataBuffer, error) in
            if let e = error {
                print(e.localizedDescription)
                return
            }
            
            //popup用view生成
            let backpopUpView = self.makeBackPopUpView()
            self.image.addSubview(backpopUpView)
            
        
            // 取得したImageのDataBufferをJpegに変換.
            let myImageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: imageDataBuffer!, previewPhotoSampleBuffer: nil)
            // JpegからUIIMageを作成.
            let myImage = UIImage(data: myImageData!)
            
            //imageViewを作ってaddSubviewする
            let staticimageView = self.makeImageView()
            staticimageView.image = myImage
            self.BackPopUpView.addSubview(staticimageView)
            
            
        })
        mode="Static"
        myButton.backgroundColor = UIColor.blue
        }else if(mode == "Static"){
            BackPopUpView.removeFromSuperview()
            StaticImageView.removeFromSuperview()
            mode="Dynamic"
            myButton.backgroundColor = UIColor.green
        }
    }
    
    //view生成
    let BackPopUpView = UIView()
    func makeBackPopUpView() -> UIView {
        BackPopUpView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
        BackPopUpView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        return BackPopUpView
    }
    
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
            myDevice.ramp(toVideoZoomFactor: CGFloat(zoom), withRate: 100000.0)
            myDevice.unlockForConfiguration()
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
    
    func pinchedGesture(gestureRecgnizer: UIPinchGestureRecognizer) {
        print("ピンチしました")
        if(mode=="Static"){//画像の拡大表示

        }else if(mode=="Dynamic"){//文字認識範囲の指定
            
        }
    }
        
    func swipedGesture(gestureRecgnizer: UISwipeGestureRecognizer) {
        print("スワイプしました")
        if(mode=="Static"){//画像の座標移動

        }
    }
}

