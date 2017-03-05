service_account = '751342725334-compute@developer.gserviceaccount.com'
credentials = ee.ServiceAccountCredentials(service_account, 'privatekey.pem')
ee.Initialize(credentials)
