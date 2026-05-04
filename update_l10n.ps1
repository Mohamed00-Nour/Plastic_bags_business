$enPath = "lib/l10n/app_en.arb"
$enArb = Get-Content $enPath -Raw | ConvertFrom-Json
$enArb | Add-Member -MemberType NoteProperty -Name "retry" -Value "Retry" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "noSalesData" -Value "No sales data yet" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "noProductsYet" -Value "No products yet" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "noOrdersYet" -Value "No orders yet" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "orderId" -Value "Order ID" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "shop" -Value "Shop" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "total" -Value "Total" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "status" -Value "Status" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "date" -Value "Date" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "actions" -Value "Actions" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "items" -Value "Items" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "newOrder" -Value "New Order" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "close" -Value "Close" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "rejectOrder" -Value "Reject Order" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "reject" -Value "Reject" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "createNewOrder" -Value "Create New Order" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "addItem" -Value "Add Item" -Force
$enArb | Add-Member -MemberType NoteProperty -Name "createOrder" -Value "Create Order" -Force
$enArb | ConvertTo-Json -Depth 10 | Out-File -FilePath $enPath -Encoding utf8

$arPath = "lib/l10n/app_ar.arb"
$arArb = Get-Content $arPath -Raw | ConvertFrom-Json
$arArb | Add-Member -MemberType NoteProperty -Name "retry" -Value "????? ????????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "noSalesData" -Value "?? ???? ?????? ?????? ???" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "noProductsYet" -Value "?? ???? ?????? ???" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "noOrdersYet" -Value "?? ???? ????? ???" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "orderId" -Value "???? ?????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "shop" -Value "?????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "total" -Value "????????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "status" -Value "??????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "date" -Value "???????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "actions" -Value "???????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "items" -Value "?????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "newOrder" -Value "??? ????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "close" -Value "?????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "rejectOrder" -Value "??? ?????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "reject" -Value "???" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "createNewOrder" -Value "????? ??? ????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "addItem" -Value "????? ????" -Force
$arArb | Add-Member -MemberType NoteProperty -Name "createOrder" -Value "????? ?????" -Force
$arArb | ConvertTo-Json -Depth 10 | Out-File -FilePath $arPath -Encoding utf8
