//
// Created by Rolando Islas on 5/22/18.
// Copyright (c) 2018 Frozen Iron Software LLC. All rights reserved.
//

import UIKit

protocol CallbackActionHandler {

    var callbackAction: ((Any, UIGestureRecognizer) -> Void)? {get set}

}
