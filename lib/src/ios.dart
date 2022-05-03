import 'dart:convert';
import 'package:icons_launcher/constants.dart';
import 'package:icons_launcher/utils.dart';
import 'package:image/image.dart';
import 'package:universal_io/io.dart';

/// File to handle the creation of icons for iOS platform
class IosIconTemplate {
  IosIconTemplate({required this.size, required this.name});

  final String name;
  final int size;
}

/// List of icons to create
List<IosIconTemplate> iosIcons = <IosIconTemplate>[
  IosIconTemplate(name: '-20x20@1x', size: 20),
  IosIconTemplate(name: '-20x20@2x', size: 40),
  IosIconTemplate(name: '-20x20@3x', size: 60),
  IosIconTemplate(name: '-29x29@1x', size: 29),
  IosIconTemplate(name: '-29x29@2x', size: 58),
  IosIconTemplate(name: '-29x29@3x', size: 87),
  IosIconTemplate(name: '-40x40@1x', size: 40),
  IosIconTemplate(name: '-40x40@2x', size: 80),
  IosIconTemplate(name: '-40x40@3x', size: 120),
  IosIconTemplate(name: '-50x50@1x', size: 50),
  IosIconTemplate(name: '-50x50@2x', size: 100),
  IosIconTemplate(name: '-57x57@1x', size: 57),
  IosIconTemplate(name: '-57x57@2x', size: 114),
  IosIconTemplate(name: '-60x60@2x', size: 120),
  IosIconTemplate(name: '-60x60@3x', size: 180),
  IosIconTemplate(name: '-72x72@1x', size: 72),
  IosIconTemplate(name: '-72x72@2x', size: 144),
  IosIconTemplate(name: '-76x76@1x', size: 76),
  IosIconTemplate(name: '-76x76@2x', size: 152),
  IosIconTemplate(name: '-83.5x83.5@2x', size: 167),
  IosIconTemplate(name: '-1024x1024@1x', size: 1024),
];

/// Create the icons
void createIcons(Map<String, dynamic> config, String? flavor) {
  final String filePath = config['image_path_ios'] ?? config['image_path'];
  // decodeImageFile shows error message if null
  // so can return here if image is null
  final Image? image = decodeImage(File(filePath).readAsBytesSync());
  if (image == null) {
    return;
  }
  if (config['remove_alpha_ios'] is bool && config['remove_alpha_ios']) {
    image.channels = Channels.rgb;
  }
  if (image.channels == Channels.rgba) {
    print(
        '\nWARNING: Icons with alpha channel are not allowed in the Apple App Store.\nSet "remove_alpha_ios: true" to remove it.\n');
  }
  String iconName;
  final dynamic iosConfig = config['ios'];
  if (flavor != null) {
    final String catalogName = 'AppIcon-$flavor';
    printStatus('Building iOS launcher icon for $flavor');
    for (IosIconTemplate template in iosIcons) {
      saveNewIcons(template, image, catalogName);
    }
    iconName = iosDefaultIconName;
    changeIosIconLauncher(catalogName, flavor);
    modifyContentsFile(catalogName);
  } else if (iosConfig is String) {
    // If the IOS configuration is a string then the user has specified a new icon to be created
    // and for the old icon file to be kept
    final String newIconName = iosConfig;
    printStatus('Adding new iOS launcher icon');
    for (IosIconTemplate template in iosIcons) {
      saveNewIcons(template, image, newIconName);
    }
    iconName = newIconName;
    changeIosIconLauncher(iconName, flavor);
    modifyContentsFile(iconName);
  }
  // Otherwise the user wants the new icon to use the default icons name and
  // update config file to use it
  else {
    printStatus('Overwriting default iOS launcher icon with new icon');
    for (IosIconTemplate template in iosIcons) {
      overwriteDefaultIcons(template, image);
    }
    iconName = iosDefaultIconName;
    changeIosIconLauncher('AppIcon', flavor);
  }
}

/// Note: Do not change interpolation unless you end up with better results (see issue for result when using cubic
/// interpolation)
void overwriteDefaultIcons(IosIconTemplate template, Image image) {
  final Image newFile = createResizedImage(template, image);
  File(iosDefaultIconFolder + iosDefaultIconName + template.name + '.png')
    ..writeAsBytesSync(encodePng(newFile));
}

/// Note: Do not change interpolation unless you end up with better results (see issue for result when using cubic
/// interpolation)
void saveNewIcons(IosIconTemplate template, Image image, String newIconName) {
  final String newIconFolder = iosAssetFolder + newIconName + '.appiconset/';
  final Image newFile = createResizedImage(template, image);
  File(newIconFolder + newIconName + template.name + '.png')
      .create(recursive: true)
      .then((File file) {
    file.writeAsBytesSync(encodePng(newFile));
  });
}

/// Create a resized image
Image createResizedImage(IosIconTemplate template, Image image) {
  if (image.width >= template.size) {
    return copyResize(image,
        width: template.size,
        height: template.size,
        interpolation: Interpolation.average);
  } else {
    return copyResize(image,
        width: template.size,
        height: template.size,
        interpolation: Interpolation.linear);
  }
}

/// Change the launcher icon to use the new icon
Future<void> changeIosIconLauncher(String iconName, String? flavor) async {
  final File iOSConfigFile = File(iosConfigFile);
  final List<String> lines = await iOSConfigFile.readAsLines();

  bool onConfigurationSection = false;
  String? currentConfig;

  for (int x = 0; x < lines.length; x++) {
    final String line = lines[x];
    if (line.contains('/* Begin XCBuildConfiguration section */')) {
      onConfigurationSection = true;
    }
    if (line.contains('/* End XCBuildConfiguration section */')) {
      onConfigurationSection = false;
    }
    if (onConfigurationSection) {
      final match = RegExp('.*/\\* (.*)\.xcconfig \\*/;').firstMatch(line);
      if (match != null) {
        currentConfig = match.group(1);
      }

      if (currentConfig != null &&
          (flavor == null || currentConfig.contains('-$flavor')) &&
          line.contains('ASSETCATALOG')) {
        lines[x] = line.replaceAll(RegExp('\=(.*);'), '= $iconName;');
      }
    }
  }

  final String entireFile = '${lines.join('\n')}\n';
  await iOSConfigFile.writeAsString(entireFile);
}

/// Create the Contents.json file
void modifyContentsFile(String newIconName) {
  final String newIconFolder =
      iosAssetFolder + newIconName + '.appiconset/Contents.json';
  File(newIconFolder).create(recursive: true).then((File contentsJsonFile) {
    final String contentsFileContent =
        generateContentsFileAsString(newIconName);
    contentsJsonFile.writeAsString(contentsFileContent);
  });
}

/// Generate the Contents json file
String generateContentsFileAsString(String newIconName) {
  final Map<String, dynamic> contentJson = <String, dynamic>{
    'images': createImageList(newIconName),
    'info': ContentsInfoObject(version: 1, author: 'xcode').toJson()
  };
  return json.encode(contentJson);
}

class ContentsImageObject {
  ContentsImageObject({
    required this.size,
    required this.idiom,
    required this.filename,
    required this.scale,
  });

  final String size;
  final String idiom;
  final String filename;
  final String scale;

  Map<String, String> toJson() {
    return <String, String>{
      'size': size,
      'idiom': idiom,
      'filename': filename,
      'scale': scale
    };
  }
}

class ContentsInfoObject {
  ContentsInfoObject({required this.version, required this.author});

  final int version;
  final String author;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'author': author,
    };
  }
}

/// Create the image list
List<Map<String, String>> createImageList(String fileNamePrefix) {
  final List<Map<String, String>> imageList = <Map<String, String>>[
    ContentsImageObject(
            size: '20x20',
            idiom: 'iphone',
            filename: '$fileNamePrefix-20x20@2x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '20x20',
            idiom: 'iphone',
            filename: '$fileNamePrefix-20x20@3x.png',
            scale: '3x')
        .toJson(),
    ContentsImageObject(
            size: '29x29',
            idiom: 'iphone',
            filename: '$fileNamePrefix-29x29@1x.png',
            scale: '1x')
        .toJson(),
    ContentsImageObject(
            size: '29x29',
            idiom: 'iphone',
            filename: '$fileNamePrefix-29x29@2x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '29x29',
            idiom: 'iphone',
            filename: '$fileNamePrefix-29x29@3x.png',
            scale: '3x')
        .toJson(),
    ContentsImageObject(
            size: '40x40',
            idiom: 'iphone',
            filename: '$fileNamePrefix-40x40@2x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '40x40',
            idiom: 'iphone',
            filename: '$fileNamePrefix-40x40@3x.png',
            scale: '3x')
        .toJson(),
    ContentsImageObject(
            size: '50x50',
            idiom: 'iphone',
            filename: '$fileNamePrefix-50x50@1x.png',
            scale: '1x')
        .toJson(),
    ContentsImageObject(
            size: '50x50',
            idiom: 'iphone',
            filename: '$fileNamePrefix-50x50@2x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '57x57',
            idiom: 'iphone',
            filename: '$fileNamePrefix-57x57@1x.png',
            scale: '1x')
        .toJson(),
    ContentsImageObject(
            size: '57x57',
            idiom: 'iphone',
            filename: '$fileNamePrefix-57x57@3x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '60x60',
            idiom: 'iphone',
            filename: '$fileNamePrefix-60x60@2x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '60x60',
            idiom: 'iphone',
            filename: '$fileNamePrefix-60x60@3x.png',
            scale: '3x')
        .toJson(),
    ContentsImageObject(
            size: '20x20',
            idiom: 'ipad',
            filename: '$fileNamePrefix-20x20@1x.png',
            scale: '1x')
        .toJson(),
    ContentsImageObject(
            size: '20x20',
            idiom: 'ipad',
            filename: '$fileNamePrefix-20x20@2x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '29x29',
            idiom: 'ipad',
            filename: '$fileNamePrefix-29x29@1x.png',
            scale: '1x')
        .toJson(),
    ContentsImageObject(
            size: '29x29',
            idiom: 'ipad',
            filename: '$fileNamePrefix-29x29@2x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '40x40',
            idiom: 'ipad',
            filename: '$fileNamePrefix-40x40@1x.png',
            scale: '1x')
        .toJson(),
    ContentsImageObject(
            size: '40x40',
            idiom: 'ipad',
            filename: '$fileNamePrefix-40x40@2x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '72x72',
            idiom: 'ipad',
            filename: '$fileNamePrefix-72x72@1x.png',
            scale: '1x')
        .toJson(),
    ContentsImageObject(
            size: '72x72',
            idiom: 'ipad',
            filename: '$fileNamePrefix-72x72@2x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '76x76',
            idiom: 'ipad',
            filename: '$fileNamePrefix-76x76@1x.png',
            scale: '1x')
        .toJson(),
    ContentsImageObject(
            size: '76x76',
            idiom: 'ipad',
            filename: '$fileNamePrefix-76x76@2x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '83.5x83.5',
            idiom: 'ipad',
            filename: '$fileNamePrefix-83.5x83.5@2x.png',
            scale: '2x')
        .toJson(),
    ContentsImageObject(
            size: '1024x1024',
            idiom: 'ios-marketing',
            filename: '$fileNamePrefix-1024x1024@1x.png',
            scale: '1x')
        .toJson()
  ];
  return imageList;
}
