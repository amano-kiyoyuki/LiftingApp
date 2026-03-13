import SwiftUI

struct PracticeView: View {
    @State private var viewModel = PracticeViewModel()
    @State private var camera = CameraManager()
    @State private var liftingCounter = LiftingCounter()
    @State private var goal = GoalManager()
    @State private var showCamera = false
    @State private var autoRecord = true
    @State private var showCelebration = false
    @State private var countEditText = ""
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            if showCamera && camera.isRunning {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()

                Color.black.opacity(0.4)
                    .ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    if goal.hasGoal {
                        goalProgressSection
                    }
                    statusSection
                    timerSection
                    counterSection
                    if showCamera && liftingCounter.isEnabled {
                        autoCountDebugSection
                    }
                    memoSection
                    saveSection
                }
                .padding()
            }

            if showCelebration {
                celebrationOverlay
            }
        }
        .task {
            await camera.requestAccess()
        }
        .onAppear {
            liftingCounter.onCount = { [weak viewModel] in
                guard let viewModel, viewModel.isActive else { return }
                viewModel.count += 1
            }
            camera.onFrame = { [weak liftingCounter] buffer in
                liftingCounter?.processFrame(buffer)
            }
        }
        .onChange(of: camera.lastRecordedURL) {
            if let url = camera.lastRecordedURL {
                viewModel.recordedVideoFileName = url.lastPathComponent
            }
        }
        .onChange(of: viewModel.count) {
            if goal.isAchieved(count: viewModel.count) && viewModel.isActive && !showCelebration {
                withAnimation(.spring(duration: 0.5)) {
                    showCelebration = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        showCelebration = false
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Text("リフティング練習")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(showCamera ? .white : .primary)

            Spacer()

            if camera.isAuthorized {
                if showCamera {
                    Button {
                        autoRecord.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "record.circle")
                                .foregroundStyle(autoRecord ? .red : .gray)
                            Text(autoRecord ? "録画ON" : "録画OFF")
                                .font(.caption)
                                .foregroundStyle(autoRecord ? .red : .gray)
                        }
                    }

                    Button {
                        camera.switchCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    .disabled(camera.isRecording)
                }

                Button {
                    if showCamera {
                        if camera.isRecording {
                            camera.stopRecording()
                        }
                        camera.stopSession()
                        showCamera = false
                        liftingCounter.isEnabled = false
                    } else {
                        showCamera = true
                        camera.startSession()
                    }
                } label: {
                    Image(systemName: showCamera ? "camera.fill" : "camera")
                        .font(.title2)
                        .foregroundStyle(showCamera ? .yellow : .primary)
                }
            }
        }
    }

    private var goalProgressSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("目標: \(goal.dailyGoal) 回")
                    .font(.subheadline)
                    .foregroundStyle(showCamera ? .white : .primary)
                Spacer()
                Text("\(viewModel.count) / \(goal.dailyGoal)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(goal.isAchieved(count: viewModel.count) ? .green : (showCamera ? .white : .primary))
            }

            ProgressView(value: goal.progress(for: viewModel.count))
                .tint(goal.isAchieved(count: viewModel.count) ? .green : .blue)
                .scaleEffect(y: 2)

            if goal.isAchieved(count: viewModel.count) {
                Text("目標達成!")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(viewModel.isActive ? "練習中" : (viewModel.didSave ? "保存済み" : "未開始"))
                    .font(.headline)
                    .foregroundStyle(viewModel.isActive ? .green : (viewModel.didSave ? .cyan : .secondary))

                if camera.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                }
            }

            if showCamera {
                Button {
                    liftingCounter.isEnabled.toggle()
                    if !liftingCounter.isEnabled {
                        liftingCounter.reset()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: liftingCounter.isEnabled ? "eye.fill" : "eye.slash")
                        Text(liftingCounter.isEnabled ? "自動カウントON" : "自動カウントOFF")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(liftingCounter.isEnabled ? Color.purple.opacity(0.2) : Color.gray.opacity(0.15))
                    )
                    .foregroundStyle(liftingCounter.isEnabled ? .purple : .secondary)
                }
            }

            if viewModel.isActive {
                Button {
                    if camera.isRecording {
                        camera.stopRecording()
                    }
                    viewModel.stop()
                } label: {
                    Text("練習終了")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            } else {
                Button {
                    viewModel.start()
                    if liftingCounter.isEnabled {
                        liftingCounter.reset()
                    }
                    if showCamera && autoRecord {
                        camera.startRecording()
                    }
                } label: {
                    Text("練習開始")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var timerSection: some View {
        Text(viewModel.elapsedText)
            .font(.system(size: 48, weight: .light, design: .monospaced))
            .foregroundStyle(viewModel.isActive ? (showCamera ? .white : .primary) : .secondary)
    }

    private var counterSection: some View {
        VStack(spacing: 12) {
            if viewModel.isEditingCount {
                countEditView
            } else {
                Text("\(viewModel.count)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(showCamera ? .white : .primary)
                    .onTapGesture {
                        countEditText = "\(viewModel.count)"
                        viewModel.isEditingCount = true
                    }
            }

            HStack(spacing: 4) {
                Text("回")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                if liftingCounter.isEnabled && viewModel.isActive {
                    Text("(自動)")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }

            HStack(spacing: 12) {
                Button(action: viewModel.decrement) {
                    Text("-1")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.count == 0)

                Button(action: viewModel.increment) {
                    Text("+1")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isActive)

                Button(action: viewModel.resetCount) {
                    Text("0")
                        .font(.title2)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var countEditView: some View {
        VStack(spacing: 8) {
            TextField("回数", text: $countEditText)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)

            HStack(spacing: 16) {
                Button("キャンセル") {
                    viewModel.isEditingCount = false
                }
                .buttonStyle(.bordered)

                Button("確定") {
                    if let value = Int(countEditText) {
                        viewModel.setCount(value)
                    }
                    viewModel.isEditingCount = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var autoCountDebugSection: some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(liftingCounter.detectionConfidence > 0.5 ? .green : (liftingCounter.detectionConfidence > 0 ? .yellow : .red))
                    .frame(width: 8, height: 8)
                Text(liftingCounter.debugStatus)
                    .font(.caption)
                    .foregroundStyle(showCamera ? .white.opacity(0.8) : .secondary)
                Spacer()
                Text("検出: \(Int(liftingCounter.detectionConfidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(showCamera ? .white.opacity(0.6) : .secondary)
            }

            HStack {
                Text("自動検出: \(liftingCounter.autoCount) 回")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Spacer()
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var memoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("メモ")
                .font(.headline)
                .foregroundStyle(showCamera ? .white : .primary)

            TextField("例: 右足多め、今日は安定", text: $viewModel.memo, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var saveSection: some View {
        VStack(spacing: 12) {
            if viewModel.recordedVideoFileName != nil && !viewModel.isActive {
                HStack(spacing: 4) {
                    Image(systemName: "film")
                    Text("録画あり")
                }
                .font(.subheadline)
                .foregroundStyle(.green)
            }

            if viewModel.canSave {
                Button {
                    viewModel.save(modelContext: modelContext)
                } label: {
                    Text("記録を保存")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }

    // MARK: - Celebration

    private var celebrationOverlay: some View {
        VStack(spacing: 16) {
            Text("目標達成!")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("\(goal.dailyGoal) 回クリア!")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.green.opacity(0.85))
        .ignoresSafeArea()
        .transition(.opacity)
        .onTapGesture {
            withAnimation {
                showCelebration = false
            }
        }
    }
}

#Preview {
    PracticeView()
        .modelContainer(for: PracticeRecord.self, inMemory: true)
}
