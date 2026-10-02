#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/runtime.h>

static NSString * const kPatchDir = @"FFPatch";
static NSString * const kPatchFile = @"patch.dat";
static NSString * const kBackupFile = @"original.backup";
static NSString * const kTargetName = @"assetindexer.U6Zffc4YIR3DslNj3cXvYGAqz58~3D";

@interface RootHelper : NSObject
+ (BOOL)copyFileFrom:(NSString *)src to:(NSString *)dst;
+ (BOOL)moveFileFrom:(NSString *)src to:(NSString *)dst;
+ (BOOL)createDirectoryAt:(NSString *)path;
+ (BOOL)removeItemAt:(NSString *)path;
+ (BOOL)loadMCM;
@end

static NSString *AppSupportDir(void) {
    NSArray *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    NSString *dir = [[urls firstObject].path stringByAppendingPathComponent:kPatchDir];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}
static NSString *StatePath(void) { return [AppSupportDir() stringByAppendingPathComponent:@"state.plist"]; }
static NSDictionary *LoadState(void) { return [NSDictionary dictionaryWithContentsOfFile:StatePath()] ?: @{}; }
static void SaveState(NSString *target, BOOL configured) {
    NSDictionary *d = @{ @"target": target ?: @"", @"configured": @(configured) };
    [d writeToFile:StatePath() atomically:YES];
}
static NSString *PatchPath(void) { return [AppSupportDir() stringByAppendingPathComponent:kPatchFile]; }
static NSString *BackupPath(void) { return [AppSupportDir() stringByAppendingPathComponent:kBackupFile]; }

// Resolve a Free Fire container. The exact bundle IDs vary by distribution, so check both.
static NSString *FindFreeFireContainer(void) {
    NSArray *roots = @[@"/var/mobile/Containers/Data/Application", @"/var/containers/Bundle/Application"];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *root in roots) {
        NSArray *dirs = [fm contentsOfDirectoryAtPath:root error:nil];
        for (NSString *uuid in dirs) {
            NSString *base = [root stringByAppendingPathComponent:uuid];
            NSString *info = [base stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:info];
            NSString *bundleID = meta[@"MCMMetadataIdentifier"] ?: meta[@"MCMMetadataIdentifierLegacy"];
            if ([bundleID isEqualToString:@"com.dts.freefireth"] || [bundleID isEqualToString:@"com.dts.freefiremax"]) return base;
        }
    }
    return nil;
}
static NSString *TargetPath(void) {
    NSString *container = FindFreeFireContainer();
    if (!container.length) return nil;
    return [[[container stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"contentcache"] stringByAppendingPathComponent:[[[@"Compulsory/ios/gameassetbundles/avatar"] stringByAppendingPathComponent:kTargetName] copy]];
}

static void Alert(UIViewController *vc, NSString *title, NSString *message) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

@interface FFPatchPickerDelegate : NSObject <UIDocumentPickerDelegate>
@property(nonatomic, weak) UIViewController *presenter;
@end
@implementation FFPatchPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    BOOL ok = [url startAccessingSecurityScopedResource];
    NSString *target = TargetPath();
    if (!target) { if (ok) [url stopAccessingSecurityScopedResource]; Alert(self.presenter, @"FF Patch", @"No se encontró el contenedor de Free Fire."); return; }
    [[NSFileManager defaultManager] removeItemAtPath:PatchPath() error:nil];
    NSError *e = nil;
    BOOL copied = [[NSFileManager defaultManager] copyItemAtURL:url toURL:[NSURL fileURLWithPath:PatchPath()] error:&e];
    if (ok) [url stopAccessingSecurityScopedResource];
    if (!copied) { Alert(self.presenter, @"FF Patch", e.localizedDescription ?: @"No se pudo guardar el parche."); return; }
    SaveState(target, YES);
    Alert(self.presenter, @"Parche configurado", @"El archivo quedó guardado. La próxima vez solo tendrás que pulsar APLICAR o RESTAURAR ORIGINAL.");
}
@end

static char kPickerKey;
static FFPatchPickerDelegate *PickerFor(UIViewController *vc) {
    FFPatchPickerDelegate *d = objc_getAssociatedObject(vc, &kPickerKey);
    if (!d) { d=[FFPatchPickerDelegate new]; d.presenter=vc; objc_setAssociatedObject(vc,&kPickerKey,d,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return d;
}

static BOOL ApplyPatch(NSError **err) {
    NSDictionary *s=LoadState(); NSString *target=s[@"target"]; if (![s[@"configured"] boolValue] || !target.length) { if(err)*err=[NSError errorWithDomain:@"FFPatch" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Primero configura el parche."}]; return NO; }
    NSFileManager *fm=[NSFileManager defaultManager];
    if (![fm fileExistsAtPath:PatchPath()]) { if(err)*err=[NSError errorWithDomain:@"FFPatch" code:2 userInfo:@{NSLocalizedDescriptionKey:@"No se encontró el parche guardado."}]; return NO; }
    if (![fm fileExistsAtPath:BackupPath()]) {
        if (![RootHelper copyFileFrom:target to:BackupPath()]) { if(err)*err=[NSError errorWithDomain:@"FFPatch" code:3 userInfo:@{NSLocalizedDescriptionKey:@"No se pudo guardar el original."}]; return NO; }
    }
    if (![RootHelper copyFileFrom:PatchPath() to:target]) { if(err)*err=[NSError errorWithDomain:@"FFPatch" code:4 userInfo:@{NSLocalizedDescriptionKey:@"No se pudo aplicar el parche."}]; return NO; }
    return YES;
}
static BOOL RestoreOriginal(NSError **err) {
    NSDictionary *s=LoadState(); NSString *target=s[@"target"]; if (![target length] || ![[NSFileManager defaultManager] fileExistsAtPath:BackupPath()]) { if(err)*err=[NSError errorWithDomain:@"FFPatch" code:5 userInfo:@{NSLocalizedDescriptionKey:@"No existe un original respaldado."}]; return NO; }
    if (![RootHelper copyFileFrom:BackupPath() to:target]) { if(err)*err=[NSError errorWithDomain:@"FFPatch" code:6 userInfo:@{NSLocalizedDescriptionKey:@"No se pudo restaurar el original."}]; return NO; }
    return YES;
}

%hook FileBrowserViewController
- (void)viewDidLoad {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc=(UIViewController *)self;
        if ([vc.view viewWithTag:73101]) return;
        UIStackView *stack=[[UIStackView alloc] initWithFrame:CGRectZero];
        stack.tag=73101; stack.axis=UILayoutConstraintAxisHorizontal; stack.spacing=8; stack.distribution=UIStackViewDistributionFillEqually; stack.translatesAutoresizingMaskIntoConstraints=NO;
        UIButton *setup=[UIButton buttonWithType:UIButtonTypeSystem]; [setup setTitle:@"CONFIGURAR PARCHE" forState:UIControlStateNormal]; setup.backgroundColor=[UIColor systemRedColor]; [setup setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; setup.layer.cornerRadius=10;
        UIButton *apply=[UIButton buttonWithType:UIButtonTypeSystem]; [apply setTitle:@"APLICAR" forState:UIControlStateNormal]; apply.backgroundColor=[UIColor systemRedColor]; [apply setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; apply.layer.cornerRadius=10;
        UIButton *restore=[UIButton buttonWithType:UIButtonTypeSystem]; [restore setTitle:@"RESTAURAR ORIGINAL" forState:UIControlStateNormal]; restore.backgroundColor=[UIColor systemRedColor]; [restore setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; restore.layer.cornerRadius=10;
        [stack addArrangedSubview:setup]; [stack addArrangedSubview:apply]; [stack addArrangedSubview:restore]; [vc.view addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.leadingAnchor constant:12],[stack.trailingAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.trailingAnchor constant:-12],[stack.bottomAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.bottomAnchor constant:-12],[stack.heightAnchor constraintEqualToConstant:44]]];
        [setup addTarget:self action:@selector(ff_configurePatch) forControlEvents:UIControlEventTouchUpInside];
        [apply addTarget:self action:@selector(ff_applyPatch) forControlEvents:UIControlEventTouchUpInside];
        [restore addTarget:self action:@selector(ff_restorePatch) forControlEvents:UIControlEventTouchUpInside];
    });
}
%new - (void)ff_configurePatch {
    UIDocumentPickerViewController *p=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[[UTType data]] asCopy:YES];
    p.delegate=PickerFor((UIViewController *)self); [self presentViewController:p animated:YES completion:nil];
}
%new - (void)ff_applyPatch { NSError *e=nil; if(ApplyPatch(&e)) Alert(self,@"APLICAR",@"Parche aplicado correctamente."); else Alert(self,@"APLICAR",e.localizedDescription); }
%new - (void)ff_restorePatch { NSError *e=nil; if(RestoreOriginal(&e)) Alert(self,@"RESTAURAR ORIGINAL",@"Original restaurado correctamente."); else Alert(self,@"RESTAURAR ORIGINAL",e.localizedDescription); }
%end
