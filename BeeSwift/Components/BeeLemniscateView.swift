import Foundation
import SpriteKit

/// An animated bee following a lemniscate (figure-eight) pattern.
/// Used to indicate server-side asynchronous work is taking place.
class BeeLemniscateView: UIView {
  // Lazily created to avoid SKView focus warning when animation isn't shown
  private var sceneContainer: SKView?
  private var scene: SKScene?
  private var beeSprite: SKSpriteNode?

  private let SpriteRelativeSize = 0.15
  private let LemniscateAspectRatio = 1.25
  private let LemniscateMaxHeight = 0.8
  private let LemniscateMaxWidth = 0.6

  override var isHidden: Bool { didSet { if isHidden { tearDownScene() } else { setUpSceneIfNeeded() } } }

  init() { super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0)) }

  required init?(coder: NSCoder) { super.init(coder: coder) }

  private func tearDownScene() {
    sceneContainer?.presentScene(nil)
    sceneContainer?.removeFromSuperview()
    sceneContainer = nil
    scene = nil
    beeSprite = nil
  }

  private func setUpSceneIfNeeded() {
    guard sceneContainer == nil else { return }

    let container = SKView()
    container.allowsTransparency = true

    let newScene = SKScene()
    newScene.backgroundColor = .clear

    let sprite = SKSpriteNode(imageNamed: "Infinibee")
    newScene.addChild(sprite)

    self.addSubview(container)
    container.snp.makeConstraints { (make) in make.edges.equalToSuperview() }
    container.presentScene(newScene)

    self.sceneContainer = container
    self.scene = newScene
    self.beeSprite = sprite

    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    guard let sceneContainer = sceneContainer, let scene = scene, let beeSprite = beeSprite else { return }

    // Resize the scene to match the container layout
    scene.size = sceneContainer.bounds.size

    // Rescale the bee sprite
    let desiredSpriteWidth = scene.size.width * SpriteRelativeSize
    let scaleFactor = desiredSpriteWidth / beeSprite.size.width
    beeSprite.setScale(scaleFactor)

    // Calculate the bounding box for the lemniscate control points
    let maximumHeightForHeight = scene.size.height * LemniscateMaxHeight
    let maximumHeightForWidth = scene.size.width * LemniscateMaxWidth / LemniscateAspectRatio

    let height = min(maximumHeightForWidth, maximumHeightForHeight)
    let width = height * LemniscateAspectRatio

    let lemniscateBounds = CGRect(
      x: (scene.size.width - width) / 2,
      y: (scene.size.height - height) / 2,
      width: width,
      height: height
    )
    let centerPoint = CGPoint(x: lemniscateBounds.midX, y: lemniscateBounds.midY)

    // Create a path for the sprite to follow
    let path = CGMutablePath()
    path.move(to: centerPoint)
    path.addCurve(
      to: centerPoint,
      control1: CGPoint(x: lemniscateBounds.maxX, y: lemniscateBounds.minY),
      control2: CGPoint(x: lemniscateBounds.maxX, y: lemniscateBounds.maxY)
    )
    path.addCurve(
      to: centerPoint,
      control1: CGPoint(x: lemniscateBounds.minX, y: lemniscateBounds.minY),
      control2: CGPoint(x: lemniscateBounds.minX, y: lemniscateBounds.maxY)
    )

    let followPath = SKAction.follow(path, asOffset: false, orientToPath: true, duration: 2.0)
    let followPathForever = SKAction.repeatForever(followPath)

    // Configure the sprite to follow the path
    beeSprite.run(followPathForever)
  }
}
