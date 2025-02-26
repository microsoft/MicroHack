@AbapCatalog.sqlViewName: 'ZBD_ISALESDOC_E'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Expanded CDS for Extraction I_Salesdocument'
define view ZBD_I_Salesdocument_E as select from I_SalesDocument {
key SalesDocument,
    //Category
    SDDocumentCategory,
    SalesDocumentType,
    SalesDocumentProcessingType,

    CreationDate,
    CreationTime,
    LastChangeDate,
    //@Semantics.systemDate.lastChangedAt: true
    LastChangeDateTime,

    //Organization
    SalesOrganization,
    DistributionChannel,
    OrganizationDivision,
    SalesGroup,
    SalesOffice,
    
    //SoldTo
    SoldToParty,
    _SoldToParty.CustomerName,
    _SoldToParty.Country,
    _SoldToParty.CityName,
    _SoldToParty.PostalCode,
    _SoldToParty.CustomerAccountGroup,
    
    //SalesDistrict
    SalesDistrict,
    
    CustomerGroup,
    CreditControlArea,
    PurchaseOrderByCustomer,
    
    //Pricing
    TotalNetAmount,
    TransactionCurrency,
    PricingDate,
    //RetailPromotion,
    //PriceDetnExchangeRate,
    //SalesDocumentCondition,
    
    //Billing
    BillingDocumentDate,
    BillingCompanyCode
} where SDDocumentCategory = 'C'
