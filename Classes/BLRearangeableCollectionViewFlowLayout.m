//
//  BLRearangeableCollectionViewFlowLayout.m
//  PanCollectionView
//
//  Created by Pszertlek on 2016/10/21.
//  Copyright © 2016年 wazrx. All rights reserved.
//

#import "BLRearangeableCollectionViewFlowLayout.h"
#import "BLRearrangeableCollectionViewCell.h"

#define angelToRandian(x)  ((x)/180.0*M_PI)

typedef NS_ENUM(NSInteger,BLDraggingAxis) {
    BLDraggingAxisFree,
    BLDraggingAxisX,
    BLDraggingAxisY,
    BLDraggingAxisXY,
};



@interface BLRearangeableBundle : NSObject

@property (nonatomic, assign) CGPoint offset;
@property (nonatomic, strong)   UIView *representationImageView;
@property (nonatomic, strong)   UICollectionViewCell *sourceCell;
@property (nonatomic, strong)   NSIndexPath *currentIndexPath;
@property (nonatomic, assign, readwrite) BOOL isEditing;
@end

@implementation BLRearangeableBundle



@end

@interface BLRearangeableCollectionViewFlowLayout()<UIGestureRecognizerDelegate>

@property (nonatomic, assign) BOOL animating;
@property (nonatomic, assign) CGRect collectionViewFrameInCanvas;
@property (nonatomic, strong) NSMutableDictionary *hitTestRectagles;
@property (nonatomic, strong) UIView *canvas;
@property (nonatomic, assign) BLDraggingAxis axis;
@property (nonatomic, strong) BLRearangeableBundle *bundle;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) CADisplayLink *edgeTimer;
@property (nonatomic, assign) BOOL edgeScrollEable;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGesture;

@end

@implementation BLRearangeableCollectionViewFlowLayout

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self setup];
        [self addNotification];
    }
    return self;
}

- (void)setup {
    if (self.collectionView) {
        self.isLongTapEnable = NO;
    }
    [self propertyInit];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setIsLongTapEnable:(BOOL)isLongTapEnable {
    _isLongTapEnable = isLongTapEnable;
    if (!isLongTapEnable) {
        [self.collectionView removeGestureRecognizer:self.longPressGesture];
        self.longPressGesture = nil;
    } else {
        if (!self.longPressGesture) {
            self.longPressGesture = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(handleGesture:)];
            self.longPressGesture.minimumPressDuration = 0.5;
            self.longPressGesture.delegate = self;
            [self.collectionView addGestureRecognizer:self.longPressGesture];
            self.canvas = self.collectionView.superview;
        }
    }
}


- (void)awakeFromNib {
    [super awakeFromNib];
    [self setup];
}

- (void)propertyInit {
    self.draggable = YES;
    self.edgeScrollEable = YES;
    self.editable = YES;
    self.isTapEndEditing = NO;
}

- (void)addNotification {
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(endEditing) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)enterEditing {
    if (!self.editable) {
        return;
    }
    if (!self.isEditing) {
        self.isEditing = YES;
        [self shakeAllCell];
        [self.collectionView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
        if (self.isTapEndEditing) {
            self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
            self.tapGesture.delegate = self;
            [self.collectionView addGestureRecognizer:self.tapGesture];
        }
    }
}

- (void)endEditing {
    if (self.isEditing) {
        self.isEditing = NO;
        [self.collectionView removeObserver:self forKeyPath:@"contentOffset"];
        [self stopShakeAllCell];
    }
}


- (void)setIsEditing:(BOOL)isEditing {
    _isEditing = isEditing;
    self.bundle = nil;
}

- (NSMutableDictionary *)hitTestRectagles {
    if (!_hitTestRectagles) {
        _hitTestRectagles = [[NSMutableDictionary alloc]init];
    }
    return _hitTestRectagles;
}

- (void)setCanvas:(UIView *)canvas {
    _canvas = canvas;
    if (!_canvas) {
        [self calculateBorders];
    }
}

- (void)prepareLayout {
    [super prepareLayout];
    [self calculateBorders];
}

- (void)calculateBorders {
    self.collectionViewFrameInCanvas = self.collectionView.frame;
    if (self.canvas!= self.collectionView.superview) {
        self.collectionViewFrameInCanvas = [self.canvas convertRect:self.collectionViewFrameInCanvas fromView:self.collectionView];
    }
    CGRect leftRect = self.collectionViewFrameInCanvas;
    leftRect.size.width = 20.0;
    self.hitTestRectagles[@"left"] = [NSValue valueWithCGRect:leftRect];
    
    CGRect topRect = self.collectionViewFrameInCanvas;
    topRect.size.height = 20.0;
    self.hitTestRectagles[@"top"] = [NSValue valueWithCGRect:topRect];

    CGRect rightRect = self.collectionViewFrameInCanvas;
    rightRect.origin.x = rightRect.size.width - 20;
    rightRect.size.width = 20;
    self.hitTestRectagles[@"right"] = [NSValue valueWithCGRect:rightRect];

    CGRect bottomRect = self.collectionViewFrameInCanvas;
    bottomRect.origin.y = bottomRect.origin.y + rightRect.size.height - 20;
    bottomRect.size.height = 20.0;
    self.hitTestRectagles[@"bottom"] = [NSValue valueWithCGRect:bottomRect];

    
}

#pragma mark --- UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        CGPoint pointOnCollectionView = [gestureRecognizer locationInView:self.collectionView];
        NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:pointOnCollectionView];
        return !indexPath;
    }
    if (!self.editable) {
        return false;
    }
    CGPoint pointPressedInCanvas = [gestureRecognizer locationInView:self.canvas];
    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        CGRect cellInCanvasFrame = [self.canvas convertRect:cell.frame fromView:self.collectionView];
        if (CGRectContainsPoint(cellInCanvasFrame, pointPressedInCanvas)) {
            if ([cell isKindOfClass:[BLRearrangeableCollectionViewCell class]]) {
                [(BLRearrangeableCollectionViewCell *)cell setIsDragging:YES];
            }
            UIGraphicsBeginImageContextWithOptions(cell.bounds.size, cell.opaque, 0);
            [cell.layer renderInContext:UIGraphicsGetCurrentContext()];
            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            UIImageView *representationImage = [[UIImageView alloc]initWithImage:img];
            
            representationImage.frame = cellInCanvasFrame;
            
            CGPoint offset = CGPointMake(pointPressedInCanvas.x - cellInCanvasFrame.origin.x, pointPressedInCanvas.y - cellInCanvasFrame.origin.y);
            
            NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
            
            self.bundle = [[BLRearangeableBundle alloc]init];
            self.bundle.offset = offset;
            self.bundle.sourceCell = cell;
            self.bundle.representationImageView = representationImage;
            self.bundle.currentIndexPath = indexPath;
        }

    }
    return (self.bundle != nil);
}

- (void)checkForDraggingAtTheEdgeAndAnimatePaging:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (self.animating) {
        return;
    }
    if (self.bundle) {
        CGRect nextPageRect = self.collectionView.bounds;
        if (self.scrollDirection == UICollectionViewScrollDirectionHorizontal) {
            CGRect leftRect = [self.hitTestRectagles[@"left"] CGRectValue];
            if (CGRectIntersectsRect(self.bundle.representationImageView.frame, leftRect)) {
                nextPageRect.origin.x -= nextPageRect.size.width;
                if (nextPageRect.origin.x < 0.0) {
                    nextPageRect.origin.x = 0;
                }
            }else if (CGRectIntersectsRect(self.bundle.representationImageView.frame, [self.hitTestRectagles[@"right"] CGRectValue])){
                nextPageRect.origin.x += nextPageRect.size.width;
                if (nextPageRect.origin.x + nextPageRect.size.width > self.collectionView.contentSize.width) {
                    nextPageRect.origin.x = self.collectionView.contentSize.width - nextPageRect.size.width;
                }
            }
        }
        else if (self.scrollDirection == UICollectionViewScrollDirectionVertical) {
            if (CGRectIntersectsRect(self.bundle.representationImageView.frame, [self.hitTestRectagles[@"top"] CGRectValue])){
                nextPageRect.origin.y -= nextPageRect.size.height;
                if (nextPageRect.origin.x < 0.0) {
                    nextPageRect.origin.x = 0.0;
                }
                
            }else if (CGRectIntersectsRect(self.bundle.representationImageView.frame, [self.hitTestRectagles[@"bottom"] CGRectValue])){
                nextPageRect.origin.y += nextPageRect.size.height;
                if (nextPageRect.origin.y + nextPageRect.size.height > self.collectionView.contentSize.height) {
                    nextPageRect.origin.y = self.collectionView.contentSize.height - nextPageRect.size.height;
                }
            }
        }
        if (!CGRectEqualToRect(nextPageRect, self.collectionView.bounds)) {
            dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, 0.8 * NSEC_PER_SEC);
            dispatch_after(delayTime, dispatch_get_main_queue(), ^{
                self.animating = false;
                if (self.isLongTapEnable) {
                    [self handleGesture:gestureRecognizer];
                }
            });
            self.animating = true;
            [self.collectionView scrollRectToVisible:nextPageRect animated:NO];
        }
    }
}

- (void)handleGesture:(UILongPressGestureRecognizer *)gesture {
    if (!self.bundle) {
        return;
    }
    if (self.editable) {
        [self enterEditing];
    }
    BLRearangeableBundle *bundle = self.bundle;
    CGPoint dragPointOnCanvas = [gesture locationInView:self.canvas];
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            
            if (self.isEditing) {
                [self shakeAllCell];
            }
            
            bundle.sourceCell.hidden = YES;
            [self.canvas addSubview:bundle.representationImageView];
            CGRect imageViewFrame = bundle.representationImageView.frame;
            CGPoint point = CGPointZero;
            point.x = dragPointOnCanvas.x - bundle.offset.x;
            point.y = dragPointOnCanvas.y - bundle.offset.y;
            
            imageViewFrame.origin = point;
            bundle.representationImageView.frame = imageViewFrame;
        }
            
            break;
        case UIGestureRecognizerStateChanged: {
            if (!self.draggable) {
                return;
            }
            CGRect imageViewFrame = bundle.representationImageView.frame;
            CGPoint point = CGPointMake(dragPointOnCanvas.x - bundle.offset.x, dragPointOnCanvas.y - bundle.offset.y);
            if (self.axis == BLDraggingAxisX) {
                point.y = imageViewFrame.origin.y;
            }
            if (self.axis == BLDraggingAxisY) {
                point.x = imageViewFrame.origin.x;
            }
            imageViewFrame.origin = point;
            bundle.representationImageView.frame = imageViewFrame;
            
            CGPoint dragPointOnCollectionView = [gesture locationInView:self.collectionView];
            NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:dragPointOnCollectionView];
            if (indexPath) {
                [self checkForDraggingAtTheEdgeAndAnimatePaging:gesture];
                if (![indexPath isEqual:bundle.currentIndexPath]) {
                    if ([self.collectionView.delegate conformsToProtocol:@protocol(BLRearangeableCollectionViewDelegate)]) {
                        id<BLRearangeableCollectionViewDelegate>delegate = self.collectionView.delegate;
                        if ([delegate respondsToSelector:@selector(rearangeableMoveItemFromIndexPath:toIndexPath:)]) {
                            [delegate rearangeableMoveItemFromIndexPath:bundle.currentIndexPath toIndexPath:indexPath];
                        }
                    }
                    [self.collectionView moveItemAtIndexPath:bundle.currentIndexPath toIndexPath:indexPath];
                    self.bundle.currentIndexPath = indexPath;
                }
            }
        }
            break;
        case UIGestureRecognizerStateEnded:{
            [self endDraggingAction:bundle];
        }
            break;
        case UIGestureRecognizerStateCancelled:{
            [self endDraggingAction:bundle];
        }
            break;
        case UIGestureRecognizerStateFailed:{
            [self endDraggingAction:bundle];
        }
            break;
        default:
            break;
    }
}

- (void)endDraggingAction:(BLRearangeableBundle *)bundle {
    bundle.sourceCell.hidden = NO;
    if ([bundle.sourceCell isKindOfClass:[BLRearrangeableCollectionViewCell class]]) {
        [(BLRearrangeableCollectionViewCell *)bundle.sourceCell setIsDragging:NO];
    }

    [bundle.representationImageView removeFromSuperview];
    [self.collectionView reloadData];
    if (_isEditing) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self shakeAllCell];
        });
    }
}

- (void)shakeAllCell{
    NSArray *cells = [self.collectionView visibleCells];
    for (UICollectionViewCell *cell in cells) {
        if (![cell isKindOfClass:[BLRearrangeableCollectionViewCell class]]) {
            continue;
        }
        [(BLRearrangeableCollectionViewCell *)cell setIsEditing:YES];
        /**如果加了shake动画就不用再加了*/
        CABasicAnimation *shake = [CABasicAnimation animationWithKeyPath:@"transform"];
        shake.duration = 0.2f;
        shake.autoreverses = YES;
        shake.repeatCount  = MAXFLOAT;
        //    shake.removedOnCompletion = NO;
        shake.fromValue = [NSValue valueWithCATransform3D:CATransform3DRotate(CATransform3DIdentity,-0.05, 0.0 ,0.0 ,1.0f)];
        shake.toValue   = [NSValue valueWithCATransform3D:CATransform3DRotate(CATransform3DIdentity, 0.05, 0.0 ,0.0 ,1.0f)];
        if (![cell.layer animationForKey:@"shake"]) {
            [cell.layer addAnimation:shake forKey:@"shake"];
        }
        if ([cell isKindOfClass:[BLRearrangeableCollectionViewCell class]]) {
            [(BLRearrangeableCollectionViewCell *)cell setIsEditing:YES];
        }
    }
}

- (void)restartShakeCell {
    [self stopShakeAllCell];
    [self shakeAllCell];
}

- (void)stopShakeAllCell{
    if (_isEditing) {
        return;
    }
    NSArray *cells = [self.collectionView visibleCells];
    for (UICollectionViewCell *cell in cells) {
        [cell.layer removeAllAnimations];
        if ([cell isKindOfClass:[BLRearrangeableCollectionViewCell class]]) {
            [(BLRearrangeableCollectionViewCell *)cell setIsEditing:NO];
        }
    }
    [self.collectionView removeGestureRecognizer:self.tapGesture];
}

- (void)tapGesture:(UITapGestureRecognizer *)tap {
    [self endEditing];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    [self shakeAllCell];
}

@end
