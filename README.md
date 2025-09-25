# trabcdefg

A new Flutter project using latest traccar openapi.yaml to generate model.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

--------screenshot
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/1.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/2.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/3.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/4.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/5.jpg) <br />
![alt text](https://raw.githubusercontent.com/onethings/trabcdefg/refs/heads/main/screenshot/6.jpg) <br />
--------screenshot


AndroidManifest.xml example in AndroidManifest.txt.

-------------------------------------------
for using latest api, Download from https://www.traccar.org/api-reference/openapi.yaml and place on /lib/openapi.yaml

run command in terminal <br />
dart pub run build_runner build


in /lib/src/generated_api/lib/ folder, 
move below folder and file to /lib/src/generated_api/ and replace it.  api, auth, model, these 3 folder. api_client.dart, api_exception.dart, api_helper.dart, api.dart, these 4 file. after replace those file, under /lib/src/generated_api/ just have above folder and file. other can delete.
-------------------------------------------

if map screen marker not correct, use this 

Future<void> _loadMarkerIcons() async {
    const List<String> categories = ['animal', 'arrow', 'bicycle', 'boat', 'bus', 'car', 'crane', 'default', 'helicopter', 'motorcycle', 'null', 'offroad', 'person', 'pickup', 'plane', 'scooter', 'ship', 'tractor', 'train', 'tram', 'trolleybus', 'truck', 'van'];
    const List<String> statuses = ['online', 'offline', 'static', 'idle', 'unknown'];
    
    // The "default" category is used for devices without a specified category.
    // The "unknown" status is used when a device's status is not available.

    for (var category in categories) {
      for (var status in statuses) {
        // Construct the file path for the marker icon
        final iconPath = 'assets/images/marker_${category}_$status.png';
        try {
          final byteData = await rootBundle.load(iconPath);
          final imageData = byteData.buffer.asUint8List();
          final codec = await ui.instantiateImageCodec(
            imageData,
            targetHeight: 100, // Customize size as needed
          );
          final frameInfo = await codec.getNextFrame();
          final image = frameInfo.image;
          final byteDataResized =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteDataResized != null) {
            final bitmap = BitmapDescriptor.fromBytes(
                byteDataResized.buffer.asUint8List());
            _markerIcons['$category-$status'] = bitmap;
          }
        } catch (e) {
          // Fallback to default if icon is not found
          print('Could not load icon: $iconPath');
          // Fallback to a default icon
        }
      }
    }
    setState(() {
      _markersLoaded = true;
    });
  }





