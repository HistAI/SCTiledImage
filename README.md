# SCTiledImage
SCTiledImage view for iOS allows you to display images with multiple layers of zoom or tiles, similar to Google Maps. This feature enables the loading of very large, high-resolution images. As the user zooms or scrolls, more details are loaded. The image must be cut into tiles of multiple levels of zoom, with level 0 being the highest resolution level. Each tile of the next level is composed of 2x2 tiles of the lower level.

### Installation
SCTiledImage is available through SPM

### Features
SCTiledImage supports:
- Displaying large images as tiles with multiple layers of zoom
- Custom tile sizes and number of zoom levels
- Gestures to zoom, pan and rotate images
- Lazy loading of images, with in-memory cache
- Displaying a low-resolution background image while tiles are loading

### Usage
1. Implement `SCTiledImageViewController`, either in code or in Interface Builder. This will be the controller that handles the gestures and sets up the view that displays the image.
2. Instantiate an object that implements the `SCTiledImageViewDataSource` protocol, and pass it to your `SCTiledImageViewController` instance through its `.setup(dataSource:)` method. Optionally, you can specify an initial scale factor and backgound color.
3. Use `.reset()` method to reset the image view to the default scale, rotation, and position.

##### DataSource
The `SCTiledImageViewDataSource` protocol requires the following:
```swift
  // delegate to call once tile images have been loaded
  weak var delegate: SCTiledImageViewDataSourceDelegate? { get set }

  // size of the full resolution image
  var imageSize: CGSize { get }

  // size of the tiles
  var tileSize: CGSize { get }

  // number of zoom levels
  var zoomLevels: Int { get }
  
  // used to return the optional background image to display when tiles are loading
  func backgroundImage() async -> UIImage?
  
  // retrieves the image for the given tile
  func tileImage(for tile: SCTile) async -> UIImage?

  // returns cached image for given tile if available, otherwise returns nil
  func cachedTileImage(for tile: SCTile) -> UIImage?
```

## License
Copyright 2016-2018 Siclo Mobile
```
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
