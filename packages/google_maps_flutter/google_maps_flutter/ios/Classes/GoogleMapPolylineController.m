// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "GoogleMapPolylineController.h"
#import "FLTGoogleMapJSONConversions.h"

@interface FLTGoogleMapPolylineController ()

@property(strong, nonatomic) GMSPolyline *polyline;
@property(weak, nonatomic) GMSMapView *mapView;

@end

@implementation FLTGoogleMapPolylineController

- (instancetype)initPolylineWithPath:(GMSMutablePath *)path
                          identifier:(NSString *)identifier
                             mapView:(GMSMapView *)mapView {
  self = [super init];
  if (self) {
    _polyline = [GMSPolyline polylineWithPath:path];
    _mapView = mapView;
    _polyline.userData = @[ identifier ];
  }
  return self;
}

- (void)removePolyline {
  self.polyline.map = nil;
}

- (void)setConsumeTapEvents:(BOOL)consumes {
  self.polyline.tappable = consumes;
}
- (void)setVisible:(BOOL)visible {
  self.polyline.map = visible ? self.mapView : nil;
}
- (void)setZIndex:(int)zIndex {
  self.polyline.zIndex = zIndex;
}
- (void)setPoints:(NSArray<CLLocation *> *)points {
  GMSMutablePath *path = [GMSMutablePath path];

  for (CLLocation *location in points) {
    [path addCoordinate:location.coordinate];
  }
  self.polyline.path = path;
}

- (void)setColor:(UIColor *)color {
  self.polyline.strokeColor = color;
}
- (void)setStrokeWidth:(CGFloat)width {
  self.polyline.strokeWidth = width;
}

- (void)setGeodesic:(BOOL)isGeodesic {
  self.polyline.geodesic = isGeodesic;
}

- (void)setSpans:(NSArray<GMSStyleSpan *> *) spans {
  self.polyline.spans = spans;
}

- (void)interpretPolylineOptions:(NSDictionary *)data
                       registrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  NSNumber *consumeTapEvents = data[@"consumeTapEvents"];
  if (consumeTapEvents && consumeTapEvents != (id)[NSNull null]) {
    [self setConsumeTapEvents:[consumeTapEvents boolValue]];
  }

  NSNumber *visible = data[@"visible"];
  if (visible && visible != (id)[NSNull null]) {
    [self setVisible:[visible boolValue]];
  }

  NSNumber *zIndex = data[@"zIndex"];
  if (zIndex && zIndex != (id)[NSNull null]) {
    [self setZIndex:[zIndex intValue]];
  }

  NSArray *points = data[@"points"];
  if (points && points != (id)[NSNull null]) {
    [self setPoints:[FLTGoogleMapJSONConversions pointsFromLatLongs:points]];
  }

  NSNumber *strokeColor = data[@"color"];
  if (strokeColor && strokeColor != (id)[NSNull null]) {
    [self setColor:[FLTGoogleMapJSONConversions colorFromRGBA:strokeColor]];
  }

  NSNumber *strokeWidth = data[@"width"];
  if (strokeWidth && strokeWidth != (id)[NSNull null]) {
    [self setStrokeWidth:[strokeWidth intValue]];
  }

  NSNumber *geodesic = data[@"geodesic"];
  if (geodesic && geodesic != (id)[NSNull null]) {
    [self setGeodesic:geodesic.boolValue];
  }
    
    NSArray *gradientValues = data[@"gradientValues"];
    NSArray *gradientColors = data[@"gradientColors"];
    if (gradientValues && gradientValues != (id)[NSNull null] && gradientColors && gradientColors != (id)[NSNull null]) {
        
        NSMutableArray<UIColor*>* colors = [NSMutableArray array];
        for (NSNumber* colorNumber in gradientColors) {
            [colors addObject:[FLTGoogleMapJSONConversions colorFromRGBA:colorNumber]];
        }
        
        NSMutableArray<UIColor*>* colorValues = [NSMutableArray array];
        CGFloat count = [colors count];
        for (NSNumber* gradientValue in gradientValues) {
            CGFloat approxIndex = MIN(MAX(gradientValue.floatValue, 0.0), 1.0) / (1.0 / (count - 1.0));
            
            NSUInteger firstIndex = floor(approxIndex);
            NSUInteger secondIndex = ceil(approxIndex);
            NSUInteger fallbackIndex = round(approxIndex);

            UIColor* firstColor = [colors objectAtIndex:firstIndex];
            UIColor* secondColor = [colors objectAtIndex:secondIndex];
            UIColor* fallbackColor = [colors objectAtIndex:fallbackIndex];

            CGFloat intermediatePercentage = approxIndex - firstIndex;
            
            CGFloat r1, g1, b1, a1;
            CGFloat r2, g2, b2, a2;
            
            if ([firstColor getRed:&r1 green:&g1 blue:&b1 alpha:&a1] == FALSE)
            {
                [colorValues addObject:fallbackColor];
                continue;
            }
            if ([secondColor getRed:&r2 green:&g2 blue:&b2 alpha:&a2] == FALSE)
            {
                [colorValues addObject:fallbackColor];
                continue;
            }
            
            UIColor* finalColor = [UIColor colorWithRed:r1 + (r2 - r1) * intermediatePercentage
                                                  green:g1 + (g2 - g1) * intermediatePercentage
                                                   blue:b1 + (b2 - b1) * intermediatePercentage
                                                  alpha:a1 + (a2 - a1) * intermediatePercentage];
            [colorValues addObject:finalColor];
        }
        
        if ([colorValues count] == self.polyline.path.count && self.polyline.path.count > 0)
        {
            NSMutableArray<GMSStyleSpan*>* spans = [NSMutableArray array];
            UIColor* lastColor = [colorValues objectAtIndex:0];
            for (int i = 1; i < self.polyline.path.count; i++) {
                UIColor* currentColor = [colorValues objectAtIndex:i];
                GMSStrokeStyle *fullGradient = [GMSStrokeStyle gradientFromColor:lastColor toColor:currentColor];
                [spans addObject:[GMSStyleSpan spanWithStyle:fullGradient]];
            }
            if ([spans count] > 0)
                [self setSpans:spans];
        }
    }
}

@end

@interface FLTPolylinesController ()

@property(strong, nonatomic) NSMutableDictionary *polylineIdentifierToController;
@property(strong, nonatomic) FlutterMethodChannel *methodChannel;
@property(weak, nonatomic) NSObject<FlutterPluginRegistrar> *registrar;
@property(weak, nonatomic) GMSMapView *mapView;

@end
;

@implementation FLTPolylinesController

- (instancetype)init:(FlutterMethodChannel *)methodChannel
             mapView:(GMSMapView *)mapView
           registrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  self = [super init];
  if (self) {
    _methodChannel = methodChannel;
    _mapView = mapView;
    _polylineIdentifierToController = [NSMutableDictionary dictionaryWithCapacity:1];
    _registrar = registrar;
  }
  return self;
}
- (void)addPolylines:(NSArray *)polylinesToAdd {
  for (NSDictionary *polyline in polylinesToAdd) {
    GMSMutablePath *path = [FLTPolylinesController getPath:polyline];
    NSString *identifier = polyline[@"polylineId"];
    FLTGoogleMapPolylineController *controller =
        [[FLTGoogleMapPolylineController alloc] initPolylineWithPath:path
                                                          identifier:identifier
                                                             mapView:self.mapView];
    [controller interpretPolylineOptions:polyline registrar:self.registrar];
    self.polylineIdentifierToController[identifier] = controller;
  }
}
- (void)changePolylines:(NSArray *)polylinesToChange {
  for (NSDictionary *polyline in polylinesToChange) {
    NSString *identifier = polyline[@"polylineId"];
    FLTGoogleMapPolylineController *controller = self.polylineIdentifierToController[identifier];
    if (!controller) {
      continue;
    }
    [controller interpretPolylineOptions:polyline registrar:self.registrar];
  }
}
- (void)removePolylineWithIdentifiers:(NSArray *)identifiers {
  for (NSString *identifier in identifiers) {
    FLTGoogleMapPolylineController *controller = self.polylineIdentifierToController[identifier];
    if (!controller) {
      continue;
    }
    [controller removePolyline];
    [self.polylineIdentifierToController removeObjectForKey:identifier];
  }
}
- (void)didTapPolylineWithIdentifier:(NSString *)identifier {
  if (!identifier) {
    return;
  }
  FLTGoogleMapPolylineController *controller = self.polylineIdentifierToController[identifier];
  if (!controller) {
    return;
  }
  [self.methodChannel invokeMethod:@"polyline#onTap" arguments:@{@"polylineId" : identifier}];
}
- (bool)hasPolylineWithIdentifier:(NSString *)identifier {
  if (!identifier) {
    return false;
  }
  return self.polylineIdentifierToController[identifier] != nil;
}
+ (GMSMutablePath *)getPath:(NSDictionary *)polyline {
  NSArray *pointArray = polyline[@"points"];
  NSArray<CLLocation *> *points = [FLTGoogleMapJSONConversions pointsFromLatLongs:pointArray];
  GMSMutablePath *path = [GMSMutablePath path];
  for (CLLocation *location in points) {
    [path addCoordinate:location.coordinate];
  }
  return path;
}

@end
