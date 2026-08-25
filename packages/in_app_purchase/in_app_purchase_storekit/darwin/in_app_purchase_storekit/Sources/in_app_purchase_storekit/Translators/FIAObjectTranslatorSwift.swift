import Foundation
import StoreKit

#if canImport(in_app_purchase_storekit_objc)
import in_app_purchase_storekit_objc
#endif

public enum FIAObjectTranslatorSwift {
  public static func getMapFrom(_ product: SKProduct) -> Any? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.getMapFromSKProduct(product)
    #else
    return nil
    #endif
  }

  public static func getMapFrom(_ period: SKProductSubscriptionPeriod) -> Any? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.getMapFromSKProductSubscriptionPeriod(period)
    #else
    return nil
    #endif
  }

  public static func getMapFrom(_ discount: SKProductDiscount) -> Any? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.getMapFromSKProductDiscount(discount)
    #else
    return nil
    #endif
  }

  public static func getMapFrom(_ payment: SKPayment) -> Any? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.getMapFromSKPayment(payment)
    #else
    return nil
    #endif
  }

  public static func getMapFrom(_ transaction: SKPaymentTransaction) -> Any? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.getMapFromSKPaymentTransaction(transaction)
    #else
    return nil
    #endif
  }

  public static func getMapFrom(_ error: NSError) -> Any? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.getMapFromNSError(error)
    #else
    return nil
    #endif
  }

  public static func getMapFrom(_ storefront: SKStorefront) -> Any? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.getMapFromSKStorefront(storefront)
    #else
    return nil
    #endif
  }

  public static func getMapFrom(_ storefront: SKStorefront, and transaction: SKPaymentTransaction) -> Any? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.getMapFromSKStorefront(storefront, andSKPaymentTransaction: transaction)
    #else
    return nil
    #endif
  }

  public static func getSKMutablePayment(fromMap map: [String: Any]) -> SKMutablePayment? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.getSKMutablePaymentFromMap(map as NSDictionary)
    #else
    return nil
    #endif
  }

  public static func getSKPaymentDiscount(fromMap map: [String: Any], withError error: inout NSString?) -> SKPaymentDiscount? {
    #if canImport(in_app_purchase_storekit_objc)
    var err: NSString? = nil
    let discount = FIAObjectTranslator.getSKPaymentDiscountFromMap(map as NSDictionary, withError: &err)
    error = err
    return discount
    #else
    return nil
    #endif
  }

  // Pigeon conversions
  public static func convertTransaction(toPigeon transaction: SKPaymentTransaction?) -> FIASKPaymentTransactionMessage? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.convertTransactionToPigeon(transaction)
    #else
    return nil
    #endif
  }

  public static func convertStorefront(toPigeon storefront: SKStorefront?) -> FIASKStorefrontMessage? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.convertStorefrontToPigeon(storefront)
    #else
    return nil
    #endif
  }

  public static func convertProductsResponse(toPigeon response: SKProductsResponse?) -> FIASKProductsResponseMessage? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.convertProductsResponseToPigeon(response)
    #else
    return nil
    #endif
  }

  public static func convertPayment(toPigeon payment: SKPayment?) -> FIASKPaymentMessage? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.convertPaymentToPigeon(payment)
    #else
    return nil
    #endif
  }

  public static func convertProduct(toPigeon product: SKProduct?) -> FIASKProductMessage? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.convertProductToPigeon(product)
    #else
    return nil
    #endif
  }

  public static func convertSKError(toPigeon error: NSError?) -> FIASKErrorMessage? {
    #if canImport(in_app_purchase_storekit_objc)
    return FIAObjectTranslator.convertSKErrorToPigeon(error)
    #else
    return nil
    #endif
  }
}
