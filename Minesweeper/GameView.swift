//
//  GameView.swift
//  Minesweeper
//
//  Created by JohnnyYin on 16/1/30.
//  Copyright © 2016年 JohnnyYin. All rights reserved.
//

import UIKit

class GameView: UIView {
    class Square {
        enum Status {
            case hide// 隐藏
            case show// 展开
            case flag// 旗帜
            case bomb// 爆炸
        }
        let rect:CGRect
        let index:Int
        var status = Status.hide
        /** 雷数 */
        var mineNum:Int = 0;
        let rowIndex:Int
        let columnIndex:Int
        var isMine:Bool = false
        
        init(rect:CGRect, index:Int, rowIndex:Int, columnIndex:Int) {
            self.rect = rect
            self.index = index
            self.rowIndex = rowIndex
            self.columnIndex = columnIndex
        }
        
        func isHide() -> Bool {
            return self.status == Status.hide
        }
    }
    
    let MAX_MINE_NUM_PERCENT = 0.16
    let GRID_SIZE = CGFloat(40);
    var horizontalPadding:CGFloat = 0
    var verticalPadding:CGFloat = 0
    let LINE_WIDTH = CGFloat(5)
    var squares = [Square]();
    let squareBgColor = UIColor(red: 244/255.0, green: 244/255.0, blue: 244/255.0, alpha: 1.0).cgColor
    let bgColor = UIColor(red: 204/255.0, green: 204/255.0, blue: 204/255.0, alpha: 1.0).cgColor
    var drawTextAttr:Dictionary<String, AnyObject>?;
    var columnNum = 0
    var rowNum = 0
    var statusHeight:CGFloat = 0
    var scoreBarHeight:CGFloat = 30
    var gameOver = false
    var mineNum = 0
    var score = 0
    var gameStartTime:Double = 0
    var pausedTime:Int = 0
    var pausedStartTime:Double = 0
    var timer:Timer?
    
    weak var viewController: UIViewController?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.frame = UIScreen.main.bounds
        
        // 点击事件
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(GameView.handleTapGesture(_:))))
        
        //长按手势
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(GameView.handleLongpressGesture(_:)))
        longPressGestureRecognizer.minimumPressDuration = 0.3
        self.addGestureRecognizer(longPressGestureRecognizer)
        
        let fieldColor: UIColor = UIColor.darkGray
        let fieldFont = UIFont.boldSystemFont(ofSize: 18)
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.alignment = NSTextAlignment.center;
        
        drawTextAttr = [
            NSForegroundColorAttributeName: fieldColor,
            NSParagraphStyleAttributeName: paraStyle,
            NSFontAttributeName: fieldFont
        ]
        
        let sizeWithLine = GRID_SIZE + LINE_WIDTH
        statusHeight = UIApplication.shared.statusBarFrame.height;
        rowNum = Int((frame.height - statusHeight - scoreBarHeight) / sizeWithLine)
        columnNum = Int(frame.width / sizeWithLine)
        horizontalPadding = (frame.width.truncatingRemainder(dividingBy: sizeWithLine)) / 2;
        verticalPadding = ((frame.height - statusHeight - scoreBarHeight).truncatingRemainder(dividingBy: sizeWithLine)) / 2
        
        squares = [Square](repeating: Square(rect: CGRect(x: 0, y: 0, width: 0, height: 0), index: -1, rowIndex: -1, columnIndex: -1), count: rowNum * columnNum)
        initGameData()
    }
    
    func initGameData() {
        let sizeWithLine = GRID_SIZE + LINE_WIDTH
        let squareCount = rowNum * columnNum
        let startX = horizontalPadding + LINE_WIDTH / 2
        let startY = verticalPadding + LINE_WIDTH / 2 + statusHeight + scoreBarHeight;
        for i in 0 ..< rowNum {// 行
            for j in 0 ..< columnNum {// 列
                let index = i * columnNum + j
                squares[index] = Square(rect: CGRect(x: startX + CGFloat(j) * sizeWithLine, y: startY + CGFloat(i) * sizeWithLine, width: GRID_SIZE, height: GRID_SIZE), index: index, rowIndex: i, columnIndex: j)
            }
        }
        
        // 放置雷
        let maxMineNum = Int(Double(squareCount) * MAX_MINE_NUM_PERCENT)
        var curMineNum = 0
        mineNum = maxMineNum
        
        func addMineNum(_ row:Int, column:Int) {
            if (row >= 0 && row < rowNum && column >= 0 && column < columnNum) {
                let square = squares[row * columnNum + column]
                if (!square.isMine) {
                    square.mineNum += 1
                }
            }
        }
        
        while (curMineNum < maxMineNum) {
            let random = Int(arc4random_uniform(UInt32(squareCount)))
            let square = squares[random]
            if (!square.isMine) {
                square.isMine = true
                addMineNum(square.rowIndex - 1, column: square.columnIndex - 1)
                addMineNum(square.rowIndex - 1, column: square.columnIndex)
                addMineNum(square.rowIndex - 1, column: square.columnIndex + 1)
                addMineNum(square.rowIndex,     column: square.columnIndex - 1)
                addMineNum(square.rowIndex,     column: square.columnIndex + 1)
                addMineNum(square.rowIndex + 1, column: square.columnIndex - 1)
                addMineNum(square.rowIndex + 1, column: square.columnIndex)
                addMineNum(square.rowIndex + 1, column: square.columnIndex + 1)
                curMineNum += 1
            }
        }
        
        gameStartTime = Date().timeIntervalSince1970
        startTimer()
    }
    
    override func didMoveToWindow() {
        var next: UIView? = self.superview;
        while next != nil {
            let nextResponder = next?.next
            if nextResponder is UIViewController {
                self.viewController = nextResponder as? UIViewController
                break
            }
            next = next!.superview;
        }
        
        // 添加应用进入后台监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(GameView.applicationForegroundBackgroundChanged(_:)),
            name: NSNotification.Name.UIApplicationDidEnterBackground,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(GameView.applicationForegroundBackgroundChanged(_:)),
            name: NSNotification.Name.UIApplicationWillEnterForeground,
            object: nil)
    }
    
    func applicationForegroundBackgroundChanged(_ notification: Notification) {
        let enterBackground = notification.name == NSNotification.Name.UIApplicationDidEnterBackground
        if (enterBackground) {
            pausedStartTime = Date().timeIntervalSince1970
            timer?.invalidate()
        } else {
            if !gameOver {
                startTimer()
            }
            if pausedStartTime <= 0 {
                return
            }
            pausedTime += Int(Date().timeIntervalSince1970 - pausedStartTime)
            pausedStartTime = 0
        }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let context:CGContext? = UIGraphicsGetCurrentContext() //获取画笔上下文
        context?.setAllowsAntialiasing(true) //抗锯齿设置
        context?.setFillColor(bgColor)
        context?.setStrokeColor(UIColor.white.cgColor)
        context?.setLineWidth(LINE_WIDTH) //设置画笔宽度
        var curFillColor = bgColor
        for square in squares {
            if square.index < 0 {
                continue
            }
            switch square.status {
            case .hide:
                fallthrough
            case .flag:
                if curFillColor !== bgColor {
                    curFillColor = bgColor
                    context?.setFillColor(curFillColor)
                }
                context?.fill(square.rect)
            case .bomb:
                fallthrough
            case .show:
                if curFillColor !== squareBgColor {
                    curFillColor = squareBgColor
                    context?.setFillColor(curFillColor)
                }
                context?.fill(square.rect)
            }
        }
        
        var flagNum = 0;
        for square in squares {
            if square.index < 0 {
                continue
            }
            switch square.status {
            case .hide:
                continue
            case .bomb:
                fallthrough
            case .flag:
                fallthrough
            case .show:
                drawTextAttr?[NSForegroundColorAttributeName] = UIColor.darkGray
                var squareStr: NSString
                if square.status == Square.Status.flag {
                    flagNum += 1
                    squareStr = "🚩"
                } else if square.status == Square.Status.bomb {
                    squareStr = "💥"
                } else if square.isMine {
                    squareStr = "💣"
                } else if square.mineNum > 0 {
                    squareStr = "\(square.mineNum)" as NSString
                    if square.mineNum > 5 {
                        drawTextAttr?[NSForegroundColorAttributeName] = UIColor.red
                    } else if square.mineNum > 3 {
                        drawTextAttr?[NSForegroundColorAttributeName] = UIColor.blue
                    } else if square.mineNum > 1 {
                        drawTextAttr?[NSForegroundColorAttributeName] = UIColor.orange
                    }
                } else {
                    continue
                }
                squareStr.draw(in: square.rect.offsetBy(dx: 0, dy: 8), withAttributes: drawTextAttr!)
            }
        }
        
        calcScore()
        let scoreBarStr = "雷数：\(mineNum - flagNum)/\(mineNum)  时间：\(parseSpendTime())  分数：\(score)"
        drawTextAttr?[NSForegroundColorAttributeName] = UIColor.darkGray
        scoreBarStr.draw(in: CGRect(x: 0, y: statusHeight + scoreBarHeight / 3, width: self.frame.width, height: scoreBarHeight), withAttributes: drawTextAttr!)
    }
    
    func parseSpendTime() -> String {
        var timeStr:String = ""
        var time = Int(Date().timeIntervalSince1970 - gameStartTime) - pausedTime
        if time > 60 * 60 {
            let t = time / 3600
            if t < 10 {
                timeStr.append("0")
            }
            timeStr.append("\(t):")
            time = time % 3600
        }
        
        var t = time / 60
        if t < 10 {
            timeStr.append("0")
        }
        timeStr.append("\(t):")
        time = time % 60
        t = time
        
        if t < 10 {
            timeStr.append("0")
        }
        timeStr.append("\(t)")
        return timeStr
    }
    
    func expand(_ row:Int, column:Int) {
        if (row < 0 || row >= rowNum || column < 0 || column >= columnNum) {
            return
        }
        let checkSquare = squares[row * columnNum + column]
        if !checkSquare.isHide() || checkSquare.isMine {
            return
        }
        if checkSquare.mineNum > 0 {
            checkSquare.status = Square.Status.show
            return
        }
        checkSquare.status = Square.Status.show
        expand(checkSquare.rowIndex - 1, column: checkSquare.columnIndex - 1)
        expand(checkSquare.rowIndex - 1, column: checkSquare.columnIndex)
        expand(checkSquare.rowIndex - 1, column: checkSquare.columnIndex + 1)
        expand(checkSquare.rowIndex,     column: checkSquare.columnIndex - 1)
        expand(checkSquare.rowIndex,     column: checkSquare.columnIndex + 1)
        expand(checkSquare.rowIndex + 1, column: checkSquare.columnIndex - 1)
        expand(checkSquare.rowIndex + 1, column: checkSquare.columnIndex)
        expand(checkSquare.rowIndex + 1, column: checkSquare.columnIndex + 1)
    }
    
    func bomb(_ index:Int) {
        calcScore()
        gameOver = true
        timer?.invalidate()
        for s in squares {
            if s.isHide() {
                s.status = Square.Status.show
                if s.index == index {
                    s.status = Square.Status.bomb
                }
            }
        }
        showAlert("踩到地雷啦~~\n分数：\(score)")
    }
    
    // 点击事件
    func handleTapGesture(_ sender: UITapGestureRecognizer){
        if (sender.state == UIGestureRecognizerState.ended) {
            if gameOver {
                restart()
                return
            }
            let point: CGPoint = sender.location(in: self)
            for square in squares {
                let hit = square.rect.contains(point)
                if (!hit) {
                    continue
                }
                switch square.status {
                case .hide:
                    if (square.isMine) {
                        bomb(square.index)
                    } else {
                        expand(square.rowIndex, column: square.columnIndex)
                    }
                    setNeedsDisplay()
                    break
                default:
                    break
                }
            }
            checkGameStatus()
        }
    }
    
    //长按手势
    func handleLongpressGesture(_ sender: UILongPressGestureRecognizer) {
        if sender.state == UIGestureRecognizerState.began {
            let point: CGPoint = sender.location(in: self)
            for square in squares {
                let hit = square.rect.contains(point)
                if (hit) {
                    switch square.status {
                    case .flag:
                        square.status = Square.Status.hide
                        setNeedsDisplay()
                        break
                    case .hide:
                        square.status = Square.Status.flag
                        setNeedsDisplay()
                        break
                    default:
                        break
                    }
                }
            }
            checkGameStatus()
        }
    }
    
    func checkGameStatus() {
        var successed = true
        for s in squares {
            successed = s.status == Square.Status.show || s.status == Square.Status.flag
            if !successed {
                break
            }
        }
        if successed {
            gameOver = true
            timer?.invalidate()
            calcScore()
            showAlert("成功啦~~\n分数：\(score)")
        }
    }
    
    /***
     * 计分规则：
     * 1. 正确的旗帜计5分
     * 2. 显示的空格计5分
     * 3. 时间过去5秒扣1分
     */
    func calcScore() {
        if gameOver {
            return
        }
        var baseScore = 0
        for s in squares {
            switch s.status {
            case .flag:
                baseScore += s.isMine ? 1 : 0
            case .show:
                baseScore += s.mineNum == 0 ? 1 : 0
            default:
                continue
            }
        }
        self.score = baseScore * 5 - (Int(Date().timeIntervalSince1970 - gameStartTime) - pausedTime) / 5
        if self.score < 0 {
            self.score = 0
        }
    }
    
    func showAlert(_ message:String) {
        let alertController = UIAlertController(title: "扫雷", message: message, preferredStyle: UIAlertControllerStyle.alert)
        let cancelAction = UIAlertAction(title: "取消", style: UIAlertActionStyle.cancel, handler: nil)
        let resetAction = UIAlertAction(title: "重新开始", style: UIAlertActionStyle.destructive, handler: {
            (alerts: UIAlertAction!) -> Void in
            self.restart()
        })
        
        alertController.addAction(resetAction)
        alertController.addAction(cancelAction)
        self.viewController?.present(alertController, animated: true, completion: nil)
    }
    
    func startTimer() {
        if timer != nil {
            timer?.invalidate()
        }
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(GameView.updateTime(_:)), userInfo: "GameTimer", repeats: true)
    }
    
    func updateTime(_ timer: Timer) {
        self.setNeedsDisplay()
    }
    
    func restart() {
        gameOver = false
        timer?.invalidate()
        score = 0
        mineNum = 0
        gameStartTime = 0
        pausedStartTime = 0
        pausedTime = 0
        initGameData()
        setNeedsDisplay()
    }
    
    deinit {
        gameOver = true
        timer?.invalidate()
    }
    
}
