//
//  BLRearangeableCollectionViewFlowLayout.h
//  PanCollectionView
//
//  Created by Pszertlek on 2016/10/21.
//  Copyright © 2016年 wazrx. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol BLRearangeableCollectionViewDelegate <UICollectionViewDelegateFlowLayout>

- (void)rearangeableMoveItemFromIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)indexPath;

@end




@interface BLRearangeableCollectionViewFlowLayout : UICollectionViewFlowLayout

@property (nonatomic, readonly) BOOL isEditing;
@property (nonatomic, assign) BOOL draggable;
@property (nonatomic, assign) BOOL editable;
@property (nonatomic, assign) BOOL isTapEndEditing;
@property (nonatomic, assign) BOOL isLongTapEnable;
- (void)enterEditing;
- (void)endEditing;
- (void)restartShakeCell;

@end
