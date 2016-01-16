//
//  ViewController.swift
//  Mineswifter
//
//  Created by Lisa Sun on 1/8/16.
//  Copyright (c) 2016 Lisa Sun. All rights reserved.
//

import UIKit
import Firebase

class ViewController: UIViewController {
    
    
    @IBOutlet weak var boardView: UIView!
    @IBOutlet weak var movesLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    // Create a reference to a Firebase location
    var myRootRef = Firebase(url:"https://minisweeper.firebaseio.com")
    var revealed:[[Bool]] = []

    let BOARD_SIZE:Int = 10
    var board:Board
    var squareButtons:[SquareButton] = []
  
    
    var oneSecondTimer:NSTimer?
    
    var moves:Int = 0 {
        didSet {
            self.movesLabel.text = "Moves: \(moves)"
            self.movesLabel.sizeToFit()
        }
    }
    var timeTaken:Int = 0  {
        didSet {
            self.timeLabel.text = "Time: \(timeTaken)"
            self.timeLabel.sizeToFit()
        }
    }

    required init(coder aDecoder: NSCoder)
    {
        self.board = Board(size: BOARD_SIZE)
        
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.initializeBoard()
        self.startNewGame()
    }
    
    func initializeFirebase() {
        myRootRef.removeValue()
        revealed.removeAll()
        for row in 0 ..< board.size {
            revealed.append(Array(count:board.size, repeatedValue:Bool()))
            for col in 0 ..< board.size {
                var tag:Int = (row * board.size) + col
                var tagString = String(tag)
                let squareItem = false
                let squareItemRef = self.myRootRef.childByAppendingPath(tagString)
                squareItemRef.setValue(squareItem)
            }
        }
    }
    
    func initializeBoard() {
        
        initializeFirebase()
        
        for row in 0 ..< board.size {
            for col in 0 ..< board.size {
                let square = board.squares[row][col]
               
                let squareSize:CGFloat = self.boardView.frame.width / CGFloat(BOARD_SIZE)
                
                let squareMargin:CGFloat = self.boardView.frame.width - (squareSize * CGFloat(BOARD_SIZE))
                
                let squareButton = SquareButton(squareModel: square, squareSize: squareSize, squareMargin: squareMargin);
                squareButton.tag = (row * board.size) + col
                squareButton.setTitle("x", forState: .Normal)
                squareButton.setTitleColor(UIColor.darkGrayColor(), forState: .Normal)
                squareButton.addTarget(self, action: "squareButtonPressed:", forControlEvents: .TouchUpInside)
                self.boardView.addSubview(squareButton)
                
                self.squareButtons.append(squareButton)
            }
        }
    }
    
    func resetBoard() {
        // reset Firebase database
        initializeFirebase()
        // resets the board with new mine locations & sets isRevealed to false for each square
        self.board.resetBoard()
        // iterates through each button and resets the text to the default value
        for squareButton in self.squareButtons {
            squareButton.setTitle("x", forState: .Normal)
        }
    }
    
    func startNewGame() {
        //start new game
        self.resetBoard()
        self.timeTaken = 0
        self.moves = 0
        self.oneSecondTimer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: Selector("oneSecond"), userInfo: nil, repeats: true)
    }
    
    func endCurrentGame() {
        self.oneSecondTimer!.invalidate()
        self.oneSecondTimer = nil
    }
    
    func oneSecond() {
        self.timeTaken++
    }
    
    @IBAction func newGamePressed() {
        self.endCurrentGame()
        self.startNewGame()
    }
    
    func convertRowColToTag(row: Int, col: Int) -> Int {
        var tag:Int = (row * board.size) + col
        return tag
    }
    
    func squareButtonPressed(sender: SquareButton) {
        if(!sender.square.isRevealed) {
            var tagString = String(sender.tag)
            self.myRootRef.childByAppendingPath(tagString).setValue(true)
            sender.square.isRevealed = true
            if(sender.square.numNeighboringMines == 0 && sender.square.isMineLocation == false) {
                clearAdjacentEmptySquares(sender)
            }
        }
        updateRevealedFromFirebase()
        updateSquareTitle()
        if sender.square.isMineLocation {
            self.minePressed()
        }
        self.moves++
        
    }
    
    func updateRevealedFromFirebase() {
        for row in 0 ..< board.size {
            for col in 0 ..< board.size {
                var tag:Int = convertRowColToTag(row, col: col)
                var tagString = String(tag)
                self.myRootRef.childByAppendingPath(tagString).observeEventType(.Value, withBlock: {
                    snapshot in
                    //                    println("\(snapshot.key) -> \(snapshot.value)")
                    if let value:Int = snapshot.value as? Int {
                        if (value == 1) {
                            self.squareButtons[tag].square.isRevealed = true
                        }
                        else {
                            self.squareButtons[tag].square.isRevealed = false
                        }
                        println("\(self.squareButtons[tag].square.isRevealed)")
                    }
                })
            }
        }
    }
    
    
    func updateSquareTitle() {
        for row in 0 ..< board.size {
            for col in 0 ..< board.size {
                var tag:Int = convertRowColToTag(row, col: col)
                if (squareButtons[tag].square.isRevealed == true) {
                    squareButtons[tag].setTitle("\(squareButtons[tag].getLabelText())", forState: .Normal)
                }
            }
        }
        
    }
    
    
    func clearAdjacentEmptySquares(button: SquareButton) {
        let offsets = [(0,1),(-1,0),(0,-1),(1,0),(-1,-1),(1,1),(-1,1),(1,-1)]
        button.square.isRevealed = true
        var tagString = String(button.tag)
        self.myRootRef.childByAppendingPath(tagString).setValue(true)
        for (rOffset,cOffset) in offsets {
            //translate tag
            var rowcol:Int = button.tag
            var row:Int = rowcol/board.size
            var col:Int = rowcol%board.size
            // getTileAtLocation might return a Square, or it might return nil, so use the optional datatype "?"
            let optionalNeighbor:SquareButton? = getEmptyTileAtLocation(button.square.row+rOffset, col: button.square.col+cOffset)
            // only evaluates true if the optional tile isn't nil
            if let neighbor = optionalNeighbor {
                clearAdjacentEmptySquares(neighbor)
            }
        }
    }
    
    func getEmptyTileAtLocation(row : Int, col : Int) -> SquareButton? {
        
        if row >= 0 && row < self.board.size && col >= 0 && col < self.board.size{
            var tag:Int = convertRowColToTag(row, col: col)
            
            if (squareButtons[tag].square.numNeighboringMines == 0 && squareButtons[tag].square.isRevealed == false && squareButtons[tag].square.isMineLocation == false) {
                return squareButtons[tag]
            }
            if (squareButtons[tag].square.isMineLocation == false) {
                squareButtons[tag].square.isRevealed = true
                var tagString = String(tag)
                self.myRootRef.childByAppendingPath(tagString).setValue(true)

            }
            
        }
        
        
        return nil
    }
    
    func minePressed() {
        self.endCurrentGame()
        // show an alert when you tap on a mine
        var alertView = UIAlertView()
        alertView.addButtonWithTitle("New Game")
        alertView.title = "BOOM!"
        alertView.message = "You tapped on a mine."
        alertView.show()
        alertView.delegate = self
    }
    
    func alertView(View: UIAlertView!, clickedButtonAtIndex buttonIndex: Int) {
        //start new game when the alert is dismissed
        self.startNewGame()
    }

}

