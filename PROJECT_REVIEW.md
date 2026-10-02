# NappStore Project Review

## Muc dich va pham vi

Tai lieu nay mo ta trang thai code dang co trong repository va danh gia cac khang dinh co the doi chieu truc tiep voi source. Day la review static: chua build, cai dat, hay chay tren iPhone jailbreak trong moi truong hien tai.

## Ket luan nhanh

- Day la ung dung iOS viet bang SwiftUI de hien thi va loc danh muc IAP, tra cuu app tren App Store, quan ly danh sach yeu thich, xem snapshot va gui lenh sang companion bridge.
- Danh sach app cai dat va danh sach IAP la hai luong du lieu tach biet. `LSApplicationWorkspace` chi duoc goi de liet ke app; code khong doc catalog IAP truc tiep tu tung app da cai.
- Catalog hien den tu file JSON/plist trong cac thu muc `IAPCheck`, hoac tu JSON reference duoc dong goi trong app. Khong co API nao trong project tu lay IAP live tu moi app cai dat.
- Code co nhanh thu `LSApplicationWorkspace`, nhung quyen root/full access va kha nang chay thanh cong tren thiet bi chua duoc chung minh. IPA build script chu dong bo cac private entitlement va ky theo cach development thong thuong.
- Co mot so sai lech da xac nhan giua giao dien, README, package metadata va hanh vi code; xem muc “Cac diem chua dung/khong khop”.

## Cau truc repository

| Duong dan | Vai tro thuc te |
| --- | --- |
| `Sources/App/IAPCheckApp.swift` | Entry point SwiftUI; mo `MainTabView` va doc tuy chon giao dien. |
| `Sources/Models/Models.swift` | Model cho IAP, offer/pricing phase, snapshot, app cai dat, log va loi. |
| `Sources/Services/StoreKitService.swift` | Nap catalog, chuyen doi export thanh `IAPItem`, favorites, metadata App Store va luong mua StoreKit/bridge. |
| `Sources/Services/InstalledAppsScanner.swift` | Thu liet ke app qua private `LSApplicationWorkspace`, bo loc system app, them app hien tai va ho tro mo app bang URL scheme. |
| `Sources/Services/TweakBridge.swift` | Doc snapshot JSON, import/export snapshot va ghi lenh `pending_buy.json` cho companion. |
| `Sources/Services/AppStoreSearchService.swift` | Tim app bang iTunes Search/Lookup API cong khai. |
| `Sources/Services/DiffEngine.swift` | So sanh hai `ScanSnapshot`: app/product moi mat, offer va mot so thay doi gia/trial. |
| `Sources/Services/DirectPaymentHandler.swift` | Helper StoreKit 1 cu; khong thay call site nao trong source hien tai. |
| `Sources/Theme/Theme.swift` | Mau sac va style dung chung. |
| `Sources/Views/MainTabView.swift` | Dieu huong 4 tab: Kham pha, Da cai dat, Thu vien, Cai dat. |
| `Sources/Views/Explore` | Danh sach goi IAP, tim app online va chi tiet san pham. |
| `Sources/Views/Installed` va `Sources/Views/Apps` | Danh sach app/catalog va man chi tiet IAP cua app. |
| `Sources/Views/Library` | Cac goi IAP da danh dau yeu thich. |
| `Sources/Views/Settings` | Tuy chon giao dien/quoc gia/payment, import va xoa du lieu. |
| `Sources/Views/Dashboard`, `History`, `Diff`, `Logs`, `Modal` | Man hinh phu/legacy va cac sheet. Mot so man khong duoc ket noi truc tiep tu 4 tab chinh. |
| `CatalogData/ReferenceCatalog` | Ba file JSON reference cho YouTube, CapCut va ChatGPT; day la snapshot dong goi, khong phai du lieu live. |
| `Package.swift` | Swift Package iOS 16, khai bao library `NappStore` gom source trong `Sources`. |
| `IAPCheck.xcodeproj` | Xcode project co app target va iOS deployment target 16.0. |
| `build_ipa.sh` | Build app bang Apple SDK/Swift compiler, ky development neu tim thay profile/identity, sau do dong goi IPA. Can macOS/Xcode command line tools. |
| `Makefile` va `control` | Cau hinh dong goi Theos/rootless. Metadata hien tai khong dong bo hoan toan voi app build. |
| `sync_reference_catalog.sh` | Chuyen JSON tu may phat trien sang app container cua NappStore bang `devicectl`; khong cho phep app doc sandbox cua app khac. |
| `Info.plist`, `entitlements*.plist` | Metadata bundle va entitlement; hai file entitlement dang rong. |
| `output/` | Artifact IPA cu dang co trong workspace; ten file hien co khong phai ten do script hien tai tao. |

## Luong chay va du lieu

### 1. Liet ke app cai dat

`InstalledAppsScanner.scanApps()` thu lay `LSApplicationWorkspace.defaultWorkspace()` va goi `allInstalledApplications`. Neu selector khong co hoac khong tra du lieu, scanner chi them app chinh no; no khong doc catalog IAP tu app cai dat. `includeSystem` phan loai dua tren chuoi `applicationType` co chua `system` hay khong, nen viec phan loai can duoc kiem tra tren iOS thuc te.

`InstalledView` hop nhat app live tu scanner voi cac app suy ra tu catalog da nap. Vi vay mot app co the hien thi trong tab “Da cai dat” chi vi co trong snapshot, ke ca scanner chua xac nhan no dang cai.

### 2. Nap catalog IAP

`StoreKitService.loadRealData()` doc de quy cac file `.json` va `.plist` trong cac duong dan:

- App container: `Documents/IAPCheck`
- `/var/mobile/Documents/IAPCheck`
- `/var/jb/var/mobile/Documents/IAPCheck`
- `/tmp/IAPCheck`

Parser chap nhan nhieu wrapper/ten truong, gom `products`, `items`, `iap`, `inAppPurchases`, `data`, `payload`, `snapshot`, va dictionary keyed by product ID. Neu cac thu muc tren khong co item hop le, service doc JSON trong `CatalogData/ReferenceCatalog` duoc bundle vao app. Reference data co the cu va provenance khong duoc code xac minh.

> Diem quan trong: day la doc catalog export/snapshot, khong phai doc IAP truc tiep tu `LSApplicationWorkspace`, StoreKit cua app khac, hay receipt container cua app khac.

### 3. Bridge va lenh cross-app

`TweakBridge` chi doc file JSON snapshot nam ngay trong cac thu muc tim kiem (khong de quy); no chap nhan `ScanSnapshot` va mot so wrapper export. Khi gui lenh, bridge ghi `pending_buy.json` vao cac duong dan ben ngoai app container, sau do gui Darwin notification va co the thu mo app dich bang URL scheme.

Viec ghi file/notification thanh cong chi co nghia la lenh da duoc xep cho bridge. No khong chung minh companion da nhan lenh, Apple da xac nhan giao dich, hay app dich da mo dung.

### 4. Thanh toan

- `StoreKit` 2 trong `StoreKitService` chi goi truc tiep cho bundle ID cua app hien tai.
- Neu item thuoc bundle ID khac, code gui lenh cho companion; app hien tai khong tu hien StoreKit sheet thay app dich.
- Che do `Direct` cung gui lenh bridge va tra trang thai pending/failed; code hien tai khong tu tao receipt va khong xac nhan giao dich Apple.
- `DirectPaymentHandler` la helper StoreKit 1 gioi han cho app hien tai va khong duoc tham chieu tu luong UI/service hien tai.

## Doi chieu cac khang dinh

| Khang dinh | Danh gia | Can cu |
| --- | --- | --- |
| “App co the liet ke app cai dat bang LSApplicationWorkspace.” | Co code thu lam dieu nay; chua duoc runtime verify. | `InstalledAppsScanner.swift` goi private selectors bang Objective-C runtime. |
| “Da liet ke app thi doc duoc IAP cua tung app.” | Khong dung theo code hien tai. | Scanner va parser catalog la hai service tach biet; catalog can JSON/plist snapshot. |
| “IAPCheck la nguon bat buoc.” | Khong hoan toan. | Service doc cac path IAPCheck truoc, sau do fallback sang reference JSON dong goi; neu khong co du lieu thi danh muc rong. Tuy nhien day van la source hien tai cua catalog ngoai app. |
| “App tu mua IAP cua app bat ky.” | Khong dung. | StoreKit request truc tiep chi chay neu bundle ID khop app hien tai; app khac can companion trong app dich. |
| “IPA build hien tai co san root/no-sandbox.” | Khong dung theo script va entitlement trong repo. | `build_ipa.sh` loai `platform-application` va `com.apple.private.security.no-sandbox`; hai entitlement plist dang rong. Cau hinh jailbreak rieng ben ngoai repo co the thay doi hanh vi, nhung chua duoc xac nhan. |

## Cac diem chua dung/khong khop da xac nhan

1. **`No-Cache Mode` chua co tac dung.** Setting duoc luu vao `@AppStorage` va hien toggle, nhung khong co code nao doc gia tri nay de doi hanh vi nap catalog. Mo ta ben duoi toggle noi “luon doc lai snapshot” nhung hien tai khong duoc thuc thi.
2. **Nguon catalog hien thi sai/le.** `dataSource` bao “Snapshot tu companion bridge” cho moi catalog doc duoc tu cac thu muc, ke ca file import trong app container. Chuoi nay khong xac dinh dung file nao/nguon nao da cung cap data.
3. **“Xoa cache catalog” khong xoa tat ca nguon.** `clearCachedCatalog()` chi xoa thu muc IAPCheck dau tien (app container), sau do nap lai tu cac path bridge/reference. Item co the xuat hien tro lai ngay sau thao tac.
4. **“Xoa sach toan bo data & reset” co pham vi rong.** `TweakBridge.clearCache()` xoa cac thu muc trong toan bo `searchPaths`, bao gom ca cac path ben ngoai app container neu process co quyen ghi. Can can nhac bao ve du lieu companion/ung dung khac.
5. **Favorites chi khoa theo product ID.** `favoriteIDs` va cap nhat `items` dung `item.id` ma khong kem bundle ID, trong khi dedup catalog da chu dong dung cap `(bundleID, id)`. Neu hai app trung ID, favorite co the bi ap dung nham/cung luc.
6. **Metadata dong goi Theos dang mo ta sai hanh vi.** `control` ghi “Direct Receipt Injection”, trong khi code ghi ro khong tao receipt va chi xep lenh bridge. `control` cung khai bao firmware tu iOS 15, nhung Package/Xcode/Makefile dang nhan iOS 16.
7. **Script sync catalog chi dem schema `items`.** No copy cac JSON bat ky nhung phan thong ke chi doc `items`; file theo schema khac co the duoc copy nhung bao tong so item sai/0. Luong runtime parser rong hon script thong ke.
8. **Artifact cu khong khop ten build moi.** `build_ipa.sh` tao `output/NappStore-dev.ipa`; workspace hien co `DiniPay.ipa` va `DiniPay.tipa`. Khong nen coi artifact cu la ket qua build cua script hien tai neu chua kiem tra timestamp/nguon tao.
9. **Mot so man la legacy/chua noi vao navigation chinh.** `MainTabView` chi chon 4 tab. Dashboard/History/Diff va mot so view cu nam trong project, nhung khong tu dong co nghia la nguoi dung co the truy cap chung tu luong chinh.

## Build va gioi han xac minh

- Build IPA theo script can macOS, `xcrun`, iPhoneOS SDK, Swift compiler, va profile/certificate neu muon IPA ky.
- Deployment target chinh trong `Package.swift` va Xcode project la iOS 16. `control` cua Theos dang ghi firmware >= 15; can thong nhat truoc khi phat hanh.
- Trong moi truong review hien tai (Windows), khong co kha nang chay build iOS/Xcode hoac runtime test tren iPhone jailbreak. IDE diagnostics truoc do khong thay loi tren mot so file, nhung khong thay the cho build.
- Can test tren thiet bi: selector `LSApplicationWorkspace`, quyen doc cac path, cach nhan dien app system, mo app bang URL scheme, va companion nhan pending command.
- Repository khong co test target/test suite duoc nhan dien trong cau truc dang co. Python reproduction truoc day chi kiem tra mot mau dictionary-keyed JSON, khong phai test Swift parser/build.

## Danh sach viec nen sua tiep

1. Chot muc tieu quyen: IPA development thong thuong hay app duoc cai/launch theo co che jailbreak co full access. Sau do lam ro signing, sandbox, va cach inject private API; khong chi dua vao `NSClassFromString`.
2. Neu muon bo phu thuoc IAPCheck, can thay source catalog bang mot producer/bridge thuc su doc StoreKit cua app dich. `LSApplicationWorkspace` mot minh khong cung cap IAP catalog.
3. Sua hoac bo `No-Cache Mode`, sua source label, va doi ten/xac nhan pham vi cac nut xoa cache.
4. Dinh danh favorite bang `(bundleID, productID)`; dong bo mo ta `control` va target OS minimum.
5. Them validation build tren macOS va runtime test tren thiet bi truoc khi ket luan jailbreak flow hoat dong.

## File tham chieu chinh

- README.md khong co trong workspace tai thoi diem kiem tra cuoi.
- [Package.swift](Package.swift)
- [Sources/Services/InstalledAppsScanner.swift](Sources/Services/InstalledAppsScanner.swift)
- [Sources/Services/StoreKitService.swift](Sources/Services/StoreKitService.swift)
- [Sources/Services/TweakBridge.swift](Sources/Services/TweakBridge.swift)
- [Sources/Views/Installed/InstalledView.swift](Sources/Views/Installed/InstalledView.swift)
- [Sources/Views/Settings/SettingsView.swift](Sources/Views/Settings/SettingsView.swift)
- [build_ipa.sh](build_ipa.sh)
- [sync_reference_catalog.sh](sync_reference_catalog.sh)
- [Makefile](Makefile)
- [control](control)