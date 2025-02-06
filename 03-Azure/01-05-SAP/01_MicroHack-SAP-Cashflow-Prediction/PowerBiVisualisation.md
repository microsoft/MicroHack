# PowerBI Visualization
In this section we'll setup some example powerBI reports.

We will be using [PowerBI Desktop](https://powerbi.microsoft.com/en-us/desktop/) for this.

## Setup & Importing Data
In PowerBI, we first need to connect to our Synapse.
* Choose `Get Data`and select `Synapse Analytics (SQL DW)`

<img src="images/powerBi/getdata.jpg" height=100>

* In the next screen fill in the server and database. You can find the server in the Azure Portal as `Dedicated SQl Endpoint` in the overview blade of your Synapse Workspace.
The Database is the SQL server pool you created.

<img src="images/powerBi/sqlendpoint.jpg" height=100>

* Select `Import Data`

<img src="images/powerBi/synapseconnection.jpg" height= 175>

* Use your Azure credentials to logon or the userid and password used during the Synapse Workspace creation.

* Select the 3 tables created in the previous steps.

<img src="images/powerBi/dataselection.jpg" height= 300>

* Select `Transform Data`
In order for all 3 tables to have the same sales order number, we'll convert the sales order number from string to integer.
In the 3 tables select the sales order number column and change the type to `Whole Number`.
The formula for the column will then change to `Table.TransformColumnTypes(dbo_SalesOrderItems,{{"SalesOrder", Int64.Type}})`.

    * For `SalesOrderHeaders`, change the `SALESDOCUMENT` column. The transformation will remove the leading zeros
    * For `SalesOrderItems`, change the `SalesOrder` column
    * For `Payments`, change the `SalesOrderNr` column

<img src="images/powerBi/whole_number.jpg">

* Select `Close & Apply`

## Create the Relational Model
In this step we'll model the relationships between the tables.
The Relationships are as follows :

`SalesOrderHeader 1:n SalesOrderItems`

`Payment 1:1 SalesOrderHeader`

* Switch to the `Model`view

<img src="images/powerBi/relationalModel.jpg">

* From the `SalesOrderHeaders`table, select the `SALESDOCUMENT`field and drag and drop it on the `SalesOrder`field of the `SalesOrderItems`table.
The relationship defaults to `1:*`

<img src="images/powerBi/SalesOrderHeadersItemsRel.jpg">

You can look at the relationship details by double clicking.

<img src="images/powerBi/SalesOrderHeadersItemsRelDetails.jpg">

* In the same way create the relationship between the `Payments`and the `SalesOrderHeaders` table using the `SalesOrderNr`and `SALESDOCUMENT`field.

* The end results looks as follows :

<img src="images/powerBi/relModel.jpg">

You can now start building the reports.

# Data Visualisation
To start the visualization, switch to the `Report` view.

<img src="images/powerBi/reportView.jpg">

Some example Reports are given beneath. Feel free to experiment.

##  Sales per Date and CustomerGroup
* Select a `Stacked Column Chart`.
* Use the `SalesOrderHeaders.CREATIONDATE` hierarchy as X-axis
* Use `SalesOrderHeaders.TOTALNETAMOUNT`as Y-axis
* Use `SalesOrderHeaders.CUSTOMERGROUP`as Legend

<img src="images/powerBi/SalesPerYearCustomerGroupSetup.jpg">
<img src="images/powerBi/SalesPerYearCustomerGroup.jpg">

>Note: You can drill down from `Year > Quarter > Month` due to the date hierarchy.

## Sales per Region and CustomerGroup
* Select `Map`.
* Use `SalesOrderHeaders.CITYNAME` as Location
* Use `SalesOrderHeaders.CUSTOMERGROUP` as Legend
* Use `SalesOrderHeaders.TOTALNETAMOUNT` as Bubble size

<img src="images/powerBi/SalesPerRegionSetup.jpg">
<img src="images/powerBi/SalesPerRegion.jpg">

>Note: when you select a CustomerGroup and Quarter in the Sales Report, the Map report will automatically update and only show this data.

<img src="images/powerBi/SalesRegionLink.jpg">

## Payments per Date and CustomerGroup
* Select a `Stacked Column Chart`
* Use `Payments.PaymentDate` hierarchy as X-axis
* Use `Payments.PaymentValue` as Y-axis
* Use `SalesOrderHeaders.CUSTOMERGROUP` as Legend

The `CustomerGroup` is retrieved via the 1:1 relationship between the `SalesOrderHeaders`and `Payments` table.

<img src="images/powerBi/PaymentDateCustGroup.jpg">

>Note : the Payments report is not identical to the Sales report. Payment of a Sales Order is typically later then the data on which the Sales Order was issued.

## Sales Per CustomerGroup and MaterialGroup
* Select a 'Stacked Bar Chart'
* Use `SalesOrderHeaders.CUSTOMERGROUP`as X-axis
* Use `SalesOrderItems.NetAmount`as Y-axis
* Use `SalesOrderItems.MaterialGroup`as Legend

<img src="images/powerBi/SalesCustMatGroup.jpg">

## Payment Offset per CustomerGroup
With this report we'll show the average number of days by which each customergroup pays his SalesOrders. Afterwards we can compare this with the outcome of our Machine Learning Model.
For this we need to join the SalesOrderHeaders and the Payment data to calculate the number of days between the billing date and the payment date.

>Note : In the ML part you created a similar view in Synapse. This section explains how you can create a 'view' locally in PowerBI.

### Merge SalesOrderHeaders and Payments
* Under `Home` select `Transform data`
* Select the `SalesOrderHeaders`table
* Select `Merge Queries > Merge Queries as New`

<img src="images/powerBi/MergeQueries.jpg">

* Define the merge with the Payments table
    * In `SalesOrderHeaders`select the `SALESDOCUMENT`column
    * In `Payments` select the `SalesOrderNr`column
    * Select `Inner Join`

<img src="images/powerBi/Merge.jpg">

* Rename the merged table to `SalesOrderPayments`

* In the `SalesOrderPayments`table select column `Payments`. Expand this column and select the fields `PaymentNr`, `PaymentDate`, `PaymentValue`, `Currency`

<img src="images/powerBi/selectPaymentFields.jpg">

* Select `Apply` under `Close & Apply`

### Calculate Payment Offset
We now need to calculate the difference between the Billing date and the actual payment date.
* Add a new `Custom Column` to the `SalesOrderPayments` table

<img src="images/powerBi/AddCustomColumn.png" height=200>

* Name the column `Offset`
* Use the following formula

```
Duration.Days([Payments.PaymentDate]-[BILLINGDOCUMENTDATE])
```

* Change the data type to `Whole Number`
* Use `Close & Apply` from the Home tab to switch to the data view

### Average Offset Report
* Swith to the reporting view
* Select a Stacked Column chart
* Use `SalesOrderPayments.CUSTOMERGROUP` as X-axis
* Use `SalesOrderPayments.Offset` as Y-axis
* Select `Average` instead of the default sum

<img src="images/powerBi/average.jpg">

<img src="images/powerBi/averageOffset.jpg">

### (Optional) Boxplot
If you'd like a more detailed view on the payment offset then you can use a 'Box Plot'. This gives you an idea of the variance on the offset.
For this you have to import a `Box and Whisker chart` visualization. 
In the `Visualizations` view, press the 3 dots and select `Get more visuals`.

<img src="images/powerBi/getMoreVisuals.jpg" height=250>

Search for `Box and Whisker chart` and press `Add`.

<img src="images/powerBi/AddBoxAndWhisker.jpg" height=150>

You can now use the chart in your visuals

* Use `SalesOrderPayments.CUSTOMERGROUP` as `Category`
* Use `SalesOrderPayments.Offset` as `Sampling`
* Use `Average of Offset` as `Value`

<img src="images/powerBi/BoxAndWhiskerChart.jpg">

From this diagram you can see that:
* CustomerGroup1 pays within 70 days +/- 10 days
* CustomerGroup2 pays within 30days +/- 5 days
* Other customergroups pay after 10 days

This should correspond to the outcome of ML Model.

Continue with the [next](PredictIncomingCashflow.md) step