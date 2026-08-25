import Foundation
import StoreKit

// Swift port of the Obj-C FIAObjectTranslator. Implemented as an enum
// with static functions to avoid exporting an Objective-C class symbol.
public enum FIAObjectTranslator {
  public static func getMapFrom(_ product: SKProduct?) -> [String: Any]? {
    guard let product = product else { return nil }
    return [
      "discounts": getMapArrayFromSKProductDiscounts(product.discounts),
      "introductoryPrice": getMapFrom(product.introductoryPrice) ?? NSNull(),
      "localizedDescription": product.localizedDescription ?? NSNull(),
      "localizedTitle": product.localizedTitle ?? NSNull(),
      "productIdentifier": product.productIdentifier ?? NSNull(),
      "price": product.price.description as Any? ?? NSNull(),
      "subscriptionGroupIdentifier": product.subscriptionGroupIdentifier ?? NSNull(),
      "subscriptionPeriod": getMapFrom(product.subscriptionPeriod) ?? NSNull(),
      "priceLocale": getMapFrom(product.priceLocale) ?? NSNull(),
    ]
  }

  @available(iOS 11.2, *)
  public static func getMapFrom(_ period: SKProductSubscriptionPeriod?) -> [String: Any]? {
    guard let period = period else { return nil }
    return ["numberOfUnits": period.numberOfUnits, "unit": period.unit]
  }

  public static func getMapArrayFromSKProductDiscounts(_ discounts: [SKProductDiscount]) -> [Any] {
    discounts.map { getMapFrom($0) as Any }
  }

  @available(iOS 11.2, *)
  public static func getMapFrom(_ discount: SKProductDiscount?) -> [String: Any]? {
    guard let discount = discount else { return nil }
    return [
      "identifier": discount.identifier ?? NSNull(),
      "numberOfPeriods": discount.numberOfPeriods,
      "paymentMode": discount.paymentMode.rawValue,
      "price": discount.price.description as Any? ?? NSNull(),
      "subscriptionPeriod": getMapFrom(discount.subscriptionPeriod) ?? NSNull(),
      "type": discount.type.rawValue,
      "priceLocale": getMapFrom(discount.priceLocale) ?? NSNull(),
    ]
  }

  public static func getMapFrom(_ productResponse: SKProductsResponse?) -> [String: Any]? {
    guard let response = productResponse else { return nil }
    let products = response.products.map { getMapFrom($0) as Any }
    return ["products": products, "invalidProductIdentifiers": response.invalidProductIdentifiers ?? []]
  }

  public static func getMapFrom(_ payment: SKPayment?) -> [String: Any]? {
    guard let payment = payment else { return nil }
    let requestDataString: Any = {
      if let data = payment.requestData, let s = String(data: data, encoding: .utf8) { return s }
      return NSNull()
    }()
    return [
      "applicationUsername": payment.applicationUsername ?? NSNull(),
      "productIdentifier": payment.productIdentifier ?? NSNull(),
      "quantity": payment.quantity,
      "requestData": requestDataString,
      "simulatesAskToBuyInSandbox": payment.simulatesAskToBuyInSandbox,
    ]
  }

  public static func getMapFrom(_ locale: NSLocale?) -> [String: Any]? {
    guard let locale = locale else { return nil }
    return [
      "currencySymbol": locale.currencySymbol ?? NSNull(),
      "currencyCode": locale.currencyCode ?? NSNull(),
      "countryCode": locale.countryCode ?? NSNull(),
    ]
  }

  public static func getSKMutablePayment(fromMap map: [String: Any]?) -> SKMutablePayment? {
    guard let map = map else { return nil }
    let payment = SKMutablePayment()
    payment.productIdentifier = map["productIdentifier"] as? String
    if let utf8String = map["requestData"] as? String { payment.requestData = utf8String.data(using: .utf8) }
    if let qty = map["quantity"] as? Int { payment.quantity = qty }
    payment.applicationUsername = map["applicationUsername"] as? String
    if let sim = map["simulatesAskToBuyInSandbox"] as? Bool { payment.simulatesAskToBuyInSandbox = sim }
    return payment
  }

  public static func getMapFrom(_ transaction: SKPaymentTransaction?) -> [String: Any]? {
    guard let transaction = transaction else { return nil }
    return [
      "error": getMapFrom(transaction.error as NSError?) ?? NSNull(),
      "payment": transaction.payment != nil ? getMapFrom(transaction.payment) as Any : NSNull(),
      "originalTransaction": transaction.originalTransaction != nil ? getMapFrom(transaction.originalTransaction) as Any : NSNull(),
      "transactionTimeStamp": transaction.transactionDate != nil ? Int(transaction.transactionDate!.timeIntervalSince1970) : NSNull(),
      "transactionIdentifier": transaction.transactionIdentifier ?? NSNull(),
      "transactionState": transaction.transactionState.rawValue,
    ]
  }

  public static func getMapFrom(_ error: NSError?) -> [String: Any]? {
    guard let error = error else { return nil }
    return ["code": error.code, "domain": error.domain, "userInfo": encodeNSErrorUserInfo(error.userInfo)]
  }

  private static func encodeNSErrorUserInfo(_ value: Any?) -> Any {
    guard let value = value else { return NSNull() }
    if let err = value as? NSError { return getMapFrom(err) as Any }
    if let url = value as? URL { return url.absoluteString }
    if let num = value as? NSNumber { return num }
    if let str = value as? String { return str }
    if let arr = value as? [Any] { return arr.map { encodeNSErrorUserInfo($0) } }
    if let dict = value as? [AnyHashable: Any] {
      var out: [AnyHashable: Any] = [:]
      for (k, v) in dict { out[k] = encodeNSErrorUserInfo(v) }
      return out
    }
    return String(format: "Unable to encode native userInfo object of type %@ to map. Please submit an issue at https://github.com/flutter/flutter/issues/new with the title \"[in_app_purchase_storekit] Unable to encode userInfo of type %@\" and add reproduction steps and the error details in the description field.", String(describing: type(of: value)), String(describing: type(of: value)))
  }

  public static func getMapFrom(_ storefront: SKStorefront?) -> [String: Any]? {
    guard let storefront = storefront else { return nil }
    return ["countryCode": storefront.countryCode, "identifier": storefront.identifier]
  }

  public static func getMapFrom(_ storefront: SKStorefront?, and transaction: SKPaymentTransaction?) -> [String: Any]? {
    guard let storefront = storefront, let transaction = transaction else { return nil }
    return ["storefront": getMapFrom(storefront) as Any, "transaction": getMapFrom(transaction) as Any]
  }

  @available(iOS 12.2, *)
  public static func getSKPaymentDiscount(fromMap map: [String: Any]?, withError error: inout NSString?) -> SKPaymentDiscount? {
    guard let map = map, !map.isEmpty else { return nil }
    let identifier = map["identifier"] as? String
    let keyIdentifier = map["keyIdentifier"] as? String
    let nonce = map["nonce"] as? String
    let signature = map["signature"] as? String
    let timestamp = map["timestamp"] as? Int

    if identifier == nil || identifier == "" {
      error = "When specifying a payment discount the 'identifier' field is mandatory." as NSString
      return nil
    }
    if keyIdentifier == nil || keyIdentifier == "" {
      error = "When specifying a payment discount the 'keyIdentifier' field is mandatory." as NSString
      return nil
    }
    if nonce == nil || nonce == "" {
      error = "When specifying a payment discount the 'nonce' field is mandatory." as NSString
      return nil
    }
    if signature == nil || signature == "" {
      error = "When specifying a payment discount the 'signature' field is mandatory." as NSString
      return nil
    }
    if timestamp == nil || timestamp! <= 0 {
      error = "When specifying a payment discount the 'timestamp' field is mandatory." as NSString
      return nil
    }

    if let uuid = UUID(uuidString: nonce!), #available(iOS 12.2, *) {
      return SKPaymentDiscount(identifier: identifier!, keyIdentifier: keyIdentifier!, nonce: uuid, signature: signature!, timestamp: NSNumber(value: timestamp!))
    }
    return nil
  }

  @available(iOS 12.2, *)
  public static func convertTransaction(toPigeon transaction: SKPaymentTransaction?) -> FIASKPaymentTransactionMessage? {
    guard let transaction = transaction else { return nil }
    return FIASKPaymentTransactionMessage.make(withPayment: convertPayment(toPigeon: transaction.payment), transactionState: convertTransactionStateToPigeon(transaction.transactionState), originalTransaction: convertTransaction(toPigeon: transaction.originalTransaction), transactionTimeStamp: NSNumber(value: transaction.transactionDate?.timeIntervalSince1970 ?? 0), transactionIdentifier: transaction.transactionIdentifier, error: convertSKError(toPigeon: transaction.error as NSError?))
  }

  public static func convertSKError(toPigeon error: NSError?) -> FIASKErrorMessage? {
    guard let error = error else { return nil }
    var userInfo: [AnyHashable: Any] = [:]
    for (k, v) in error.userInfo { userInfo[k] = encodeNSErrorUserInfo(v) }
    return FIASKErrorMessage.make(withCode: error.code, domain: error.domain, userInfo: userInfo)
  }

  public static func convertTransactionStateToPigeon(_ state: SKPaymentTransactionState) -> FIASKPaymentTransactionStateMessage {
    switch state {
    case .purchasing: return .purchasing
    case .purchased: return .purchased
    case .failed: return .failed
    case .restored: return .restored
    case .deferred: return .deferred
    @unknown default: return .purchasing
    }
  }

  @available(iOS 12.2, *)
  public static func convertPayment(toPigeon payment: SKPayment?) -> FIASKPaymentMessage? {
    guard let payment = payment else { return nil }
    let requestDataString = payment.requestData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    return FIASKPaymentMessage.make(withProductIdentifier: payment.productIdentifier, applicationUsername: payment.applicationUsername, requestData: requestDataString, quantity: payment.quantity, simulatesAskToBuyInSandbox: payment.simulatesAskToBuyInSandbox, paymentDiscount: convertPaymentDiscountToPigeon(payment.paymentDiscount))
  }

  @available(iOS 12.2, *)
  public static func convertPaymentDiscountToPigeon(_ discount: SKPaymentDiscount?) -> FIASKPaymentDiscountMessage? {
    guard let discount = discount else { return nil }
    return FIASKPaymentDiscountMessage.make(withIdentifier: discount.identifier, keyIdentifier: discount.keyIdentifier, nonce: discount.nonce?.uuidString, signature: discount.signature, timestamp: discount.timestamp.intValue)
  }

  @available(iOS 13.0, *)
  public static func convertStorefront(toPigeon storefront: SKStorefront?) -> FIASKStorefrontMessage? {
    guard let storefront = storefront else { return nil }
    return FIASKStorefrontMessage.make(withCountryCode: storefront.countryCode, identifier: storefront.identifier)
  }

  @available(iOS 12.2, *)
  public static func convertSKProductSubscriptionPeriodToPigeon(_ period: SKProductSubscriptionPeriod?) -> FIASKProductSubscriptionPeriodMessage? {
    guard let period = period else { return nil }
    let unit: FIASKSubscriptionPeriodUnitMessage
    switch period.unit {
    case .day: unit = .day
    case .week: unit = .week
    case .month: unit = .month
    case .year: unit = .year
    @unknown default: unit = .day
    }
    return FIASKProductSubscriptionPeriodMessage.make(withNumberOfUnits: period.numberOfUnits, unit: unit)
  }

  @available(iOS 12.2, *)
  public static func convertProductDiscountToPigeon(_ productDiscount: SKProductDiscount?) -> FIASKProductDiscountMessage? {
    guard let pd = productDiscount else { return nil }
    let paymentMode: FIASKProductDiscountPaymentModeMessage
    switch pd.paymentMode {
    case .freeTrial: paymentMode = .freeTrial
    case .payAsYouGo: paymentMode = .payAsYouGo
    case .payUpFront: paymentMode = .payUpFront
    @unknown default: paymentMode = .freeTrial
    }
    let type: FIASKProductDiscountTypeMessage = pd.type == .introductory ? .introductory : .subscription
    return FIASKProductDiscountMessage.make(withPrice: pd.price.description, priceLocale: convertNSLocaleToPigeon(pd.priceLocale), numberOfPeriods: pd.numberOfPeriods, paymentMode: paymentMode, subscriptionPeriod: convertSKProductSubscriptionPeriodToPigeon(pd.subscriptionPeriod), identifier: pd.identifier, type: type)
  }

  @available(iOS 12.2, *)
  public static func convertNSLocaleToPigeon(_ locale: NSLocale?) -> FIASKPriceLocaleMessage? {
    guard let locale = locale else { return nil }
    return FIASKPriceLocaleMessage.make(withCurrencySymbol: locale.currencySymbol, currencyCode: locale.currencyCode, countryCode: locale.countryCode)
  }

  @available(iOS 12.2, *)
  public static func convertProductToPigeon(_ product: SKProduct?) -> FIASKProductMessage? {
    guard let product = product else { return nil }
    let pigeonDiscounts = product.discounts.map { convertProductDiscountToPigeon($0) }
    return FIASKProductMessage.make(withProductIdentifier: product.productIdentifier, localizedTitle: product.localizedTitle, localizedDescription: product.localizedDescription, priceLocale: convertNSLocaleToPigeon(product.priceLocale), subscriptionGroupIdentifier: product.subscriptionGroupIdentifier, price: product.price.description, subscriptionPeriod: convertSKProductSubscriptionPeriodToPigeon(product.subscriptionPeriod), introductoryPrice: convertProductDiscountToPigeon(product.introductoryPrice), discounts: pigeonDiscounts as [Any])
  }

  @available(iOS 12.2, *)
  public static func convertProductsResponse(toPigeon productsResponse: SKProductsResponse?) -> FIASKProductsResponseMessage? {
    guard let productsResponse = productsResponse else { return nil }
    let pigeonProducts = productsResponse.products.map { convertProductToPigeon($0) }
    return FIASKProductsResponseMessage.make(withProducts: pigeonProducts as [Any], invalidProductIdentifiers: productsResponse.invalidProductIdentifiers ?? [])
  }
}
