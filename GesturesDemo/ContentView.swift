//
//  ContentView.swift
//  GesturesDemo
//
//  Created by Nien Lam on 9/29/21.
//

import SwiftUI
import ARKit
import RealityKit
import Combine


// MARK: - View model for handling communication between the UI and ARView.
class ViewModel: ObservableObject {
    let uiSignal = PassthroughSubject<UISignal, Never>()
    
    @Published var anchorSet = false

    enum UISignal {
        case resetAnchor
    }
}


// MARK: - UI Layer.
struct ContentView : View {
    @StateObject var viewModel: ViewModel
    
    var body: some View {
        ZStack {
            // AR View.
            ARViewContainer(viewModel: viewModel)
        
            // Reset button.
            Button {
                viewModel.uiSignal.send(.resetAnchor)
            } label: {
                Label("Reset", systemImage: "gobackward")
                    .font(.system(.title))
                    .foregroundColor(.white)
                    .labelStyle(IconOnlyLabelStyle())
                    .frame(width: 44, height: 44)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
    }
}


// MARK: - AR View.
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ViewModel
    
    func makeUIView(context: Context) -> ARView {
        SimpleARView(frame: .zero, viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class SimpleARView: ARView {
    var viewModel: ViewModel
    var arView: ARView { return self }
    var subscriptions = Set<AnyCancellable>()
    
    var planeAnchor: AnchorEntity?
    

    // Custom entities.
    var collisionBlockA: CollisionBlock!
    var collisionBlockB: CollisionBlock!

    
    init(frame: CGRect, viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        setupScene()
        
        setupEntities()
    }
        
    func setupScene() {
        // Setup world tracking and plane detection.
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.environmentTexturing = .automatic
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]
        arView.session.run(configuration)
        
        // Called every frame.
        scene.subscribe(to: SceneEvents.Update.self) { event in
            self.renderLoop()
        }.store(in: &subscriptions)
        
        // Process UI signals.
        viewModel.uiSignal.sink { [weak self] in
            self?.processUISignal($0)
        }.store(in: &subscriptions)
    
        // Respond to collision events.
        arView.scene.subscribe(to: CollisionEvents.Began.self) { event in

            print("💥 Collision with \(event.entityA.name) & \(event.entityB.name)")

        }.store(in: &subscriptions)

        
        // Setup tap gesture.
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        arView.addGestureRecognizer(tap)

        //
        // Uncomment to show collision debug.
        // arView.debugOptions = [.showPhysics]
    }

    // Process UI signals.
    func processUISignal(_ signal: ViewModel.UISignal) {
        switch signal {
        case .resetAnchor:
            resetPlaneAnchor()
        }
    }

    // Handle taps.
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        guard let touchInView = sender?.location(in: self),
              let hitEntity = arView.entity(at: touchInView) else { return }

        print("👇 Did tap \(hitEntity.name)")
        
        // Respond to tap event.
        hitEntity.scale *= [1.2, 1.2, 1.2]
    }

    func setupEntities() {
        collisionBlockA = CollisionBlock(name: "BlockA", size: 0.1, color: UIColor.red)
        arView.installGestures(.all, for: collisionBlockA)

        collisionBlockB = CollisionBlock(name: "BlockB", size: 0.2, color: UIColor.green)
        arView.installGestures(.all, for: collisionBlockB)
    }
    
    func resetPlaneAnchor() {
        planeAnchor?.removeFromParent()
        planeAnchor = nil
        
        planeAnchor = AnchorEntity(plane: [.horizontal])
        arView.scene.addAnchor(planeAnchor!)
        
        collisionBlockA.position.x = -0.15
        collisionBlockA.scale = [1,1,1]
        planeAnchor?.addChild(collisionBlockA)

        collisionBlockB.position.x = 0.15
        collisionBlockB.scale = [1,1,1]
        planeAnchor?.addChild(collisionBlockB)
    }

    func renderLoop() {
        // Keep blocks aligned to top of plane.
        collisionBlockA.position.y = collisionBlockA.visualBounds(relativeTo: planeAnchor).extents.y / 2
        collisionBlockB.position.y = collisionBlockB.visualBounds(relativeTo: planeAnchor).extents.y / 2
    }
}


// MARK: - Collision Block Entity
class CollisionBlock: Entity, HasModel, HasCollision {
    init(name: String, size: Float, color: UIColor) {
        super.init()
        self.model = ModelComponent(
            mesh: .generateBox(size: size, cornerRadius: 0.01),
            materials: [SimpleMaterial(color: color, isMetallic: false)]
        )
        
        self.name = name
        
        // Set collision shape.
        self.collision = CollisionComponent(shapes: [.generateBox(size: [size, size, size])])
    }

    required init() {
        fatalError("init() has not been implemented")
    }
}
