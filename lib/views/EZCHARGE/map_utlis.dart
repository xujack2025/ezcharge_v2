import 'package:url_launcher/url_launcher.dart';

class MapUtlis{
  MapUtlis._();

  static Future<void>openMap(
      double Latitude,
      double Longtitude,
  )async{
    String googleMapUrl =
        "https://www.google.com/maps/search/?api=1&query=$Latitude,$Longtitude";

    if(await canLaunch(googleMapUrl)){
      await launch(googleMapUrl);
    }
    else{
      throw 'Could not open the Map';
    }

  }
}