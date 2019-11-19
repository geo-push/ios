## Подключение через CocoaPods:

```
  pod 'GeoPush', :git => 'https://github.com/geo-push/ios.git'
```

В CocoaPods поставляется universal сборка, для публикации в AppStore нужно убрать лишние архитектуры. 
Для этого можно использовать sh-скрипт, который нужно добавить в BuildPhases после шага Embed frameworks:

```
APP_PATH="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"

# This script loops through the frameworks embedded in the application and
# removes unused architectures.
find "$APP_PATH" -name '*.framework' -type d | while read -r FRAMEWORK
do
    FRAMEWORK_EXECUTABLE_NAME=$(defaults read "$FRAMEWORK/Info.plist" CFBundleExecutable)
    FRAMEWORK_EXECUTABLE_PATH="$FRAMEWORK/$FRAMEWORK_EXECUTABLE_NAME"
    echo "Executable is $FRAMEWORK_EXECUTABLE_PATH"

    EXTRACTED_ARCHS=()

    for ARCH in $ARCHS
    do
        echo "Extracting $ARCH from $FRAMEWORK_EXECUTABLE_NAME"
        lipo -extract "$ARCH" "$FRAMEWORK_EXECUTABLE_PATH" -o "$FRAMEWORK_EXECUTABLE_PATH-$ARCH"
        EXTRACTED_ARCHS+=("$FRAMEWORK_EXECUTABLE_PATH-$ARCH")
    done

    echo "Merging extracted architectures: ${ARCHS}"
    lipo -o "$FRAMEWORK_EXECUTABLE_PATH-merged" -create "${EXTRACTED_ARCHS[@]}"
    rm "${EXTRACTED_ARCHS[@]}"

    echo "Replacing original executable with thinned version"
    rm "$FRAMEWORK_EXECUTABLE_PATH"
    mv "$FRAMEWORK_EXECUTABLE_PATH-merged" "$FRAMEWORK_EXECUTABLE_PATH"

done
```

## Настройка отправки геопозиции:

В файл Info.plist нужно добавить следующие строки:

```
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Для того, чтобы смотреть выгодные предложения и скидки на карте рядом с вами, разершите приложению доступ к вашему местоположению.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Для того, чтобы смотреть выгодные предложения и скидки на карте рядом с вами, разершите приложению доступ к вашему местоположению.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Для того, чтобы смотреть выгодные предложения и скидки на карте рядом с вами, разершите приложению доступ к вашему местоположению.</string>
 ```
 NSLocationAlwaysAndWhenInUseUsageDescription, NSLocationAlwaysUsageDescription, NSLocationWhenInUseUsageDescription - это пояснение для пользователя, для чего приложение будет использовать его геопозицию. 
 
 
Далее в настройках проекта, во вкладке Capabilities нужно включить Background modes и выбрать в списке Location updates и Remote notifications, как показано на рисунке:
 
 <img width="608" alt="Скриншот 2019-07-31 12 57 02" src="https://user-images.githubusercontent.com/2930268/62203555-16c43580-b394-11e9-943c-9025de66c25c.png">
 
 Затем нужно вызвать метод начала трекинга геопозиции:
 
  ```
  import GeoPush
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        UGPLocation.shared.startTracking()
        
        return true
    }
  ```
 
 Также имеется возможность отправки геопозиции, только если приложение уже ранее получило разрешение на использование геопозиции пользователя. 
 
 ```
 import GeoPush
 
 func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
       
       UGPLocation.shared.startTrackingIfHasPermission()
       
       return true
   }
 ```
 
 ## Настройка push-сообщений:
 
 Регистрируемся на получение push-сообщений:
 
  ```
  private func registerForUserNotifications() {
        
        if #available(iOS 10, *) {
            
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                print("access to user notifications is granted: \(granted), error: \(String(describing: error?.localizedDescription))")
                
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        } else {
            
            let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
   ```

Далее в методе делегата отправляем push token устройства: 

```
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        UGPPushAPI.sendPushToken(deviceToken: deviceToken)
    }
```

Для того, чтобы отправить метку о прочтении пуша, нужно вызвать метод markPushOpened в методе делегата:

```
func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler:
        @escaping (UIBackgroundFetchResult) -> Void
        ) {
        UGPPushAPI.markPushOpened(userInfo: userInfo)
    }
```

Для того, чтобы отправить метку о получении пуша, нужно добавить в проект UNNotificationServiceExtension. Инструкцию как это сделать можно найти тут: https://stackoverflow.com/questions/40040583/how-to-use-notification-service-extension-with-unnotification-in-ios10. В методе didRecieve нужно вызвать метод библиотеки UGPPushAPI.markPushDelivered(userInfo: request.content.userInfo)


Пример реализации:

```
import UserNotifications
import GeoPush

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        UGPPushAPI.markPushDelivered(userInfo: request.content.userInfo)
        
        if let bestAttemptContent = bestAttemptContent {
            
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
```


 ## Настройка отправки данных о пользователе:

```
import GeoPush
      
UGPPushAPI.sendUserInfo(["name": "User Name"])
```
