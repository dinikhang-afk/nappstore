#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

// Darwin notification NappStore listens for
static NSString *const kNotifyName = @"com.adr.checkiap.trigger_buy";

// Build paths at runtime to avoid RootHide compile-time string patching.
// RootHide rewrites literal paths like "/var/mobile/Documents/IAPCheck" in
// the binary, causing the tweak to write to a redirected location that
// NappStore cannot see. Constructing the path dynamically bypasses this.
static NSString *outputDirectory(void) {
    // Build path from components at runtime to avoid RootHide binary patching.
    // NSHomeDirectory() returns the app's own sandbox when injected, so we
    // construct /var/mobile/Documents/IAPCheck manually.
    NSMutableString *path = [NSMutableString stringWithString:@"/va"];
    [path appendString:@"r/mobi"];
    [path appendString:@"le/Documen"];
    [path appendString:@"ts/IAPCheck"];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    if ([fm isWritableFileAtPath:path]) {
        return [path copy];
    }
    // Fallback: /tmp/IAPCheck
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:@"IAPCheck"];
    [fm createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:nil];
    return tmp;
}

static void ensureDirectory(NSString *path) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

// Period helper — must be declared before serializeProduct
static NSString *periodStringFromPeriod(id subscriptionPeriod) {
    if (@available(iOS 11.2, *)) {
        SKProductSubscriptionPeriod *period = subscriptionPeriod;
        if (!period) return @"";
        switch (period.unit) {
            case SKProductPeriodUnitDay:   return [NSString stringWithFormat:@"%luD", (unsigned long)period.numberOfUnits];
            case SKProductPeriodUnitWeek:  return [NSString stringWithFormat:@"%luW", (unsigned long)period.numberOfUnits];
            case SKProductPeriodUnitMonth: return [NSString stringWithFormat:@"%luM", (unsigned long)period.numberOfUnits];
            case SKProductPeriodUnitYear:  return [NSString stringWithFormat:@"%luY", (unsigned long)period.numberOfUnits];
        }
    }
    return @"";
}

static NSDictionary *serializeProduct(SKProduct *product) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"productId"] = product.productIdentifier ?: @"";
    dict[@"title"] = product.localizedTitle ?: @"";
    dict[@"description"] = product.localizedDescription ?: @"";

    // Product type heuristic: subscriptionPeriod exists → subscription
    NSString *productType = @"INAPP";
    if (@available(iOS 11.2, *)) {
        if (product.subscriptionPeriod && product.subscriptionPeriod.numberOfUnits > 0) {
            productType = @"SUBS";
        }
    }
    dict[@"productType"] = productType;

    // Price formatting
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = product.priceLocale;
    NSString *formatted = [formatter stringFromNumber:product.price] ?: @"N/A";
    dict[@"formattedBasePrice"] = formatted;

    // Trial & intro discount detection
    BOOL hasTrial = NO;
    BOOL hasIntroDiscount = NO;
    NSMutableArray *offers = [NSMutableArray array];

    if (@available(iOS 11.2, *)) {
        SKProductDiscount *intro = product.introductoryPrice;
        if (intro) {
            if (intro.paymentMode == SKProductDiscountPaymentModeFreeTrial) {
                hasTrial = YES;
            } else {
                hasIntroDiscount = YES;
            }
            NSNumberFormatter *introFmt = [[NSNumberFormatter alloc] init];
            introFmt.numberStyle = NSNumberFormatterCurrencyStyle;
            introFmt.locale = intro.priceLocale;
            NSString *introPrice = [introFmt stringFromNumber:intro.price] ?: @"Free";
            NSString *classification;
            if (intro.paymentMode == SKProductDiscountPaymentModeFreeTrial) {
                classification = @"FREE_TRIAL";
            } else {
                classification = @"INTRO_DISCOUNT";
            }
            [offers addObject:@{
                @"classification": classification,
                @"summaryText": [NSString stringWithFormat:@"%@ intro", introPrice],
                @"pricingPhases": @[@{
                    @"formattedPrice": introPrice,
                    @"billingPeriod": periodStringFromPeriod(intro.subscriptionPeriod),
                    @"billingCycleCount": @(intro.numberOfPeriods)
                }]
            }];
        }
    }

    if (@available(iOS 12.2, *)) {
        for (SKProductDiscount *discount in product.discounts) {
            NSNumberFormatter *dFmt = [[NSNumberFormatter alloc] init];
            dFmt.numberStyle = NSNumberFormatterCurrencyStyle;
            dFmt.locale = discount.priceLocale;
            NSString *dPrice = [dFmt stringFromNumber:discount.price] ?: @"";
            [offers addObject:@{
                @"offerId": discount.identifier ?: @"",
                @"classification": @"INTRO_DISCOUNT",
                @"summaryText": [NSString stringWithFormat:@"%@ promo", dPrice],
                @"pricingPhases": @[@{
                    @"formattedPrice": dPrice,
                    @"billingPeriod": periodStringFromPeriod(discount.subscriptionPeriod),
                    @"billingCycleCount": @(discount.numberOfPeriods)
                }]
            }];
            hasIntroDiscount = YES;
        }
    }

    dict[@"hasFreeTrial"] = @(hasTrial);
    dict[@"hasIntroDiscount"] = @(hasIntroDiscount);
    dict[@"offers"] = offers;

    return [dict copy];
}



static void writeSnapshot(NSString *bundleId, NSArray<NSDictionary *> *products) {
    if (products.count == 0) return;

    NSString *dir = outputDirectory();
    ensureDirectory(dir);

    NSDictionary *snapshot = @{
        @"bundleId": bundleId,
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"products": products
    };

    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:snapshot
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:&error];
    if (!json) {
        NSLog(@"[IAPDumper] JSON serialize error: %@", error);
        return;
    }

    NSString *filename = [NSString stringWithFormat:@"%@_iap.json", bundleId];
    NSString *path = [dir stringByAppendingPathComponent:filename];
    [json writeToFile:path atomically:YES];

    NSLog(@"[IAPDumper] Wrote %lu products for %@ → %@",
          (unsigned long)products.count, bundleId, path);

    // Notify NappStore
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFNotificationName)kNotifyName,
        NULL, NULL, true);
}

// MARK: - Hook SKProductsResponse delivery

%hook SKProductsRequest

- (void)start {
    // Store the request so we can identify the delegate callback
    %orig;
}

%end

// Hook the delegate callback. The delegate is set by the host app; we swizzle
// the delivery point on SKProductsRequest's internal completion path so we see
// every response regardless of which class acts as delegate.

%hook NSObject

// productsRequest:didReceiveResponse: is the SKProductsRequestDelegate method.
// We hook it on NSObject so we intercept every delegate regardless of class.
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    %orig;

    @try {
        NSArray<SKProduct *> *products = response.products;
        if (products.count == 0) return;

        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if (!bundleId || bundleId.length == 0) return;

        // Skip NappStore itself
        if ([bundleId isEqualToString:@"dev.dothanh.nappstore"]) return;

        NSMutableArray *serialized = [NSMutableArray arrayWithCapacity:products.count];
        for (SKProduct *product in products) {
            [serialized addObject:serializeProduct(product)];
        }

        // Write on background thread to avoid blocking the app
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            writeSnapshot(bundleId, [serialized copy]);
        });
    } @catch (NSException *e) {
        NSLog(@"[IAPDumper] Exception: %@", e);
    }
}

%end
