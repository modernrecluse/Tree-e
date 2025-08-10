import SwiftUI
import Foundation

// MARK: - Data Models

struct TreeNode: Identifiable, Codable, Equatable {
    let id: String
    var content: String
    var level: Int
    var note: String
    var isTask: Bool
    var isCompleted: Bool
    
    init(id: String = UUID().uuidString, content: String, level: Int = 0, note: String = "", isTask: Bool = false, isCompleted: Bool = false) {
        self.id = id
        self.content = content
        self.level = level
        self.note = note
        self.isTask = isTask
        self.isCompleted = isCompleted
    }
}

struct Tree: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var nodes: [TreeNode]
    var parentTreeId: String?
    var parentNodeId: String?
    var breadcrumb: [String]
    
    init(id: String = UUID().uuidString, title: String, nodes: [TreeNode] = [], parentTreeId: String? = nil, parentNodeId: String? = nil, breadcrumb: [String] = []) {
        self.id = id
        self.title = title
        self.nodes = nodes
        self.parentTreeId = parentTreeId
        self.parentNodeId = parentNodeId
        self.breadcrumb = breadcrumb
    }
}

struct AppTheme: Codable, Equatable {
    let name: String
    let background: String
    let text: String
    let prompt: String
    let border: String
    let levelColors: [String]
    
    func colorForLevel(_ level: Int) -> Color {
        let colorIndex = level < levelColors.count ? level : level % levelColors.count
        return Color(hex: levelColors[colorIndex])
    }
    
    var backgroundColor: Color { Color(hex: background) }
    var textColor: Color { Color(hex: text) }
    var promptColor: Color { Color(hex: prompt) }
    var borderColor: Color { Color(hex: border) }
}

// MARK: - Themes

struct Themes {
    static let matcha = AppTheme(
        name: "Matcha",
        background: "#e9f5e9",
        text: "#2e4a2e",
        prompt: "#59784a",
        border: "#c4d6c4",
        levelColors: ["#f0f8f0", "#ddf2dd", "#ccedcc", "#bae8ba", "#a9e3a9"]
    )
    
    static let latte = AppTheme(
        name: "Latte",
        background: "#f5f0e9",
        text: "#4a3e2e",
        prompt: "#7a6b59",
        border: "#d6ccc4",
        levelColors: ["#f8f5f0", "#edebdd", "#e3dccc", "#d9cfba", "#cfc2a9"]
    )
    
    static let ocean = AppTheme(
        name: "Ocean",
        background: "#e9f0f5",
        text: "#2e3e4a",
        prompt: "#596b7a",
        border: "#c4ccd6",
        levelColors: ["#f0f5f8", "#ddebf2", "#ccddec", "#bacfe8", "#a9c2e3"]
    )
    
    static let midnight = AppTheme(
        name: "Midnight",
        background: "#0f0f24",
        text: "#e1e1e1",
        prompt: "#8c8c8c",
        border: "#2e2e45",
        levelColors: ["#1a1a2e", "#24243a", "#2e2e42", "#38384e", "#424256"]
    )
    
    static let all: [String: AppTheme] = [
        "matcha": matcha,
        "latte": latte,
        "ocean": ocean,
        "midnight": midnight
    ]
}

enum NodeFilter: String, CaseIterable {
    case all = "all"
    case tasks = "tasks"
    case notes = "notes"
    case branched = "branched"
    
    var label: String {
        switch self {
        case .all: return "All Nodes"
        case .tasks: return "Tasks"
        case .notes: return "With Notes"
        case .branched: return "Branched"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "◎"
        case .tasks: return "□"
        case .notes: return "◊"
        case .branched: return "⫷"
        }
    }
}

// MARK: - Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Data Store

class TreeDataStore: ObservableObject {
    @Published var trees: [Tree] = []
    @Published var activeTreeIndex: Int = 0
    @Published var currentTheme: String = "matcha"
    @Published var currentFilter: NodeFilter = .all
    
    private let treesKey = "tree-e-trees"
    private let themeKey = "tree-e-theme"
    
    init() {
        loadTrees()
        loadTheme()
    }
    
    // MARK: - Persistence
    func saveTrees() {
        if let data = try? JSONEncoder().encode(trees) {
            UserDefaults.standard.set(data, forKey: treesKey)
        }
    }
    
    func loadTrees() {
        if let data = UserDefaults.standard.data(forKey: treesKey),
           let decodedTrees = try? JSONDecoder().decode([Tree].self, from: data) {
            trees = decodedTrees
        } else {
            trees = [Tree(id: "main", title: "Main Tree")]
        }
        
        if trees.isEmpty {
            trees = [Tree(id: "main", title: "Main Tree")]
        }
    }
    
    func saveTheme() {
        UserDefaults.standard.set(currentTheme, forKey: themeKey)
    }
    
    func loadTheme() {
        currentTheme = UserDefaults.standard.string(forKey: themeKey) ?? "matcha"
    }
    
    // MARK: - Tree Management
    func addNode(content: String, toTreeIndex treeIndex: Int, afterNodeId nodeId: String? = nil, level: Int = 0) {
        guard treeIndex < trees.count else { return }
        
        let newNode = TreeNode(content: content, level: level)
        
        if let nodeId = nodeId,
           let insertIndex = trees[treeIndex].nodes.firstIndex(where: { $0.id == nodeId }) {
            let insertAfterIndex = findInsertionPoint(in: trees[treeIndex].nodes, after: insertIndex)
            trees[treeIndex].nodes.insert(newNode, at: insertAfterIndex + 1)
        } else {
            trees[treeIndex].nodes.append(newNode)
        }
        
        saveTrees()
    }
    
    private func findInsertionPoint(in nodes: [TreeNode], after index: Int) -> Int {
        guard index < nodes.count else { return nodes.count - 1 }
        
        let parentLevel = nodes[index].level
        var insertAfterIndex = index
        
        for i in (index + 1)..<nodes.count {
            if nodes[i].level > parentLevel {
                insertAfterIndex = i
            } else {
                break
            }
        }
        
        return insertAfterIndex
    }
    
    func deleteNode(nodeId: String, fromTreeIndex treeIndex: Int) {
        guard treeIndex < trees.count else { return }
        trees[treeIndex].nodes.removeAll { $0.id == nodeId }
        saveTrees()
    }
    
    func updateNode(nodeId: String, inTreeIndex treeIndex: Int, update: (inout TreeNode) -> Void) {
        guard treeIndex < trees.count,
              let nodeIndex = trees[treeIndex].nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        
        update(&trees[treeIndex].nodes[nodeIndex])
        saveTrees()
    }
    
    func branchOut(nodeId: String, fromTreeIndex treeIndex: Int) {
        guard treeIndex < trees.count,
              trees.count < 5,
              let nodeIndex = trees[treeIndex].nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        
        let selectedNode = trees[treeIndex].nodes[nodeIndex]
        let currentTree = trees[treeIndex]
        
        // Find all child nodes
        var nodeAndChildren: [TreeNode] = []
        let parentLevel = selectedNode.level
        
        for i in nodeIndex..<trees[treeIndex].nodes.count {
            let node = trees[treeIndex].nodes[i]
            if i == nodeIndex {
                var rootNode = node
                rootNode.level = 0
                nodeAndChildren.append(rootNode)
            } else if node.level > parentLevel {
                var childNode = node
                childNode.level = node.level - parentLevel
                nodeAndChildren.append(childNode)
            } else {
                break
            }
        }
        
        let truncatedTitle = selectedNode.content.count > 20 
            ? String(selectedNode.content.prefix(17)) + "..."
            : selectedNode.content
        
        var newBreadcrumb = currentTree.breadcrumb
        if currentTree.id != "main" {
            newBreadcrumb.append(currentTree.title)
        }
        
        if newBreadcrumb.count > 3 {
            newBreadcrumb = Array(newBreadcrumb.prefix(1)) + ["..."] + Array(newBreadcrumb.suffix(2))
        }
        
        let newTree = Tree(
            title: truncatedTitle,
            nodes: nodeAndChildren,
            parentTreeId: currentTree.id,
            parentNodeId: selectedNode.id,
            breadcrumb: newBreadcrumb
        )
        
        trees.append(newTree)
        activeTreeIndex = trees.count - 1
        saveTrees()
    }
    
    func closeTree(treeIndex: Int) {
        guard treeIndex < trees.count,
              let treeToClose = trees[safe: treeIndex],
              let parentTreeId = treeToClose.parentTreeId,
              let parentNodeId = treeToClose.parentNodeId else { return }
        
        guard let parentTreeIndex = trees.firstIndex(where: { $0.id == parentTreeId }) else { return }
        
        var parentTree = trees[parentTreeIndex]
        
        guard let originalNodeIndex = parentTree.nodes.firstIndex(where: { $0.id == parentNodeId }) else { return }
        
        let originalNode = parentTree.nodes[originalNodeIndex]
        let removeUntilIndex = findInsertionPoint(in: parentTree.nodes, after: originalNodeIndex) + 1
        
        let updatedNodes = treeToClose.nodes.map { node in
            var updatedNode = node
            updatedNode.level = node.level + originalNode.level
            return updatedNode
        }
        
        parentTree.nodes.replaceSubrange(originalNodeIndex..<removeUntilIndex, with: updatedNodes)
        trees[parentTreeIndex] = parentTree
        
        trees.remove(at: treeIndex)
        
        if activeTreeIndex >= treeIndex {
            activeTreeIndex = max(0, activeTreeIndex - 1)
        }
        
        saveTrees()
    }
    
    func getFilteredNodes(from nodes: [TreeNode]) -> [TreeNode] {
        switch currentFilter {
        case .all:
            return nodes
        case .tasks:
            return nodes.filter { $0.isTask }
        case .notes:
            return nodes.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .branched:
            return nodes.filter { node in
                trees.contains { $0.parentNodeId == node.id }
            }
        }
    }
    
    func isNodeBranchedOut(_ nodeId: String) -> Bool {
        return trees.contains { $0.parentNodeId == nodeId }
    }
    
    func clearAll() {
        trees = [Tree(id: "main", title: "Main Tree")]
        activeTreeIndex = 0
        saveTrees()
    }
}

// MARK: - Node View

struct NodeView: View {
    let node: TreeNode
    let theme: AppTheme
    let isSelected: Bool
    let treesLength: Int
    let isBranchedOut: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onToggleTask: () -> Void
    let onToggleComplete: () -> Void
    let onFocus: () -> Void
    let onBranchOut: () -> Void
    let onDelete: () -> Void
    let onIndent: () -> Void
    let onOutdent: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Indentation spacers
            ForEach(0..<node.level, id: \.self) { _ in
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 36)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Node content
                HStack(spacing: 12) {
                    // Task toggle
                    if node.isTask {
                        Button(action: onToggleComplete) {
                            Image(systemName: node.isCompleted ? "checkmark.square.fill" : "square")
                                .foregroundColor(node.isCompleted ? .green : theme.textColor.opacity(0.6))
                                .font(.system(size: 18))
                        }
                    }
                    
                    // Node text
                    Text(node.content)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(theme.textColor)
                        .strikethrough(node.isTask && node.isCompleted)
                        .opacity(node.isTask && node.isCompleted ? 0.6 : 1.0)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // Node icons
                    HStack(spacing: 4) {
                        if node.isTask {
                            Image(systemName: "square")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textColor.opacity(0.6))
                        }
                        
                        if !node.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Image(systemName: "note.text")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textColor.opacity(0.6))
                        }
                        
                        if isBranchedOut {
                            Image(systemName: "arrow.branch")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? theme.borderColor : theme.colorForLevel(node.level))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? theme.textColor : theme.borderColor, lineWidth: isSelected ? 2 : 1)
                        )
                )
                .opacity(isBranchedOut ? 0.7 : 1.0)
                .scaleEffect(isSelected ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            withAnimation {
                                dragOffset = .zero
                            }
                            
                            if value.translation.x > 50 {
                                onIndent()
                            } else if value.translation.x < -50 {
                                onOutdent()
                            }
                        }
                )
                .onTapGesture {
                    onTap()
                }
                
                // Action buttons when selected
                if isSelected {
                    HStack(spacing: 8) {
                        if !isBranchedOut {
                            ActionButton(title: "Edit", icon: "pencil", color: .indigo, action: onEdit)
                        }
                        
                        ActionButton(title: node.isTask ? "Note" : "Task", icon: "square", color: .green, action: onToggleTask)
                        ActionButton(title: "Notes", icon: "note.text", color: .blue, action: onFocus)
                        ActionButton(title: "Branch", icon: "arrow.branch", color: .mint, action: onBranchOut, disabled: treesLength >= 5 || isBranchedOut)
                        ActionButton(title: "Delete", icon: "trash", color: .red, action: onDelete)
                    }
                    .padding(.leading, 12)
                }
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    let disabled: Bool
    
    init(title: String, icon: String, color: Color, action: @escaping () -> Void, disabled: Bool = false) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
        self.disabled = disabled
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(disabled ? Color.gray : color)
            .foregroundColor(.white)
            .cornerRadius(6)
        }
        .disabled(disabled)
        .scaleEffect(disabled ? 0.95 : 1.0)
        .opacity(disabled ? 0.6 : 1.0)
    }
}

// MARK: - Focus View

struct FocusView: View {
    let node: TreeNode
    let theme: AppTheme
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var noteText: String
    
    init(node: TreeNode, theme: AppTheme, onSave: @escaping (String) -> Void) {
        self.node = node
        self.theme = theme
        self.onSave = onSave
        _noteText = State(initialValue: node.note)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Node content display
                HStack(spacing: 12) {
                    if node.isTask {
                        Image(systemName: node.isCompleted ? "checkmark.square.fill" : "square")
                            .foregroundColor(node.isCompleted ? .green : theme.textColor.opacity(0.6))
                            .font(.system(size: 18))
                    }
                    
                    Text(node.content)
                        .font(.body.bold())
                        .foregroundColor(theme.textColor)
                        .strikethrough(node.isTask && node.isCompleted)
                        .opacity(node.isTask && node.isCompleted ? 0.6 : 1.0)
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.colorForLevel(node.level))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.borderColor, lineWidth: 1)
                        )
                )
                
                // Note editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundColor(theme.textColor)
                    
                    TextEditor(text: $noteText)
                        .font(.body)
                        .foregroundColor(theme.textColor)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.colorForLevel(1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(theme.borderColor, lineWidth: 1)
                                )
                        )
                        .frame(minHeight: 200)
                }
                
                Spacer()
            }
            .padding()
            .background(theme.backgroundColor)
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(theme.textColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(noteText)
                    }
                    .foregroundColor(theme.textColor)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var dataStore = TreeDataStore()
    @State private var currentInput = ""
    @State private var currentIndentLevel = 0
    @State private var selectedNodeId: String?
    @State private var editingNodeId: String?
    @State private var focusedNode: TreeNode?
    @State private var showAbout = false
    @State private var showClearConfirm = false
    @State private var showThemeDropdown = false
    @State private var editText = ""
    @FocusState private var isInputFocused: Bool
    @FocusState private var isEditingFocused: Bool
    
    private var currentTree: Tree? {
        dataStore.trees[safe: dataStore.activeTreeIndex]
    }
    
    private var currentTheme: AppTheme {
        Themes.all[dataStore.currentTheme] ?? Themes.matcha
    }
    
    private var filteredNodes: [TreeNode] {
        guard let tree = currentTree else { return [] }
        return dataStore.getFilteredNodes(from: tree.nodes)
    }
    
    var body: some View {
        ZStack {
            currentTheme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Main content
                mainContentView
                
                // Input area
                inputAreaView
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView(theme: currentTheme)
        }
        .sheet(isPresented: Binding<Bool>(
            get: { focusedNode != nil },
            set: { if !$0 { focusedNode = nil } }
        )) {
            if let node = focusedNode {
                FocusView(node: node, theme: currentTheme) { updatedNote in
                    dataStore.updateNode(nodeId: node.id, inTreeIndex: dataStore.activeTreeIndex) { updatedNode in
                        updatedNode.note = updatedNote
                    }
                    focusedNode = nil
                }
            }
        }
        .alert("Clear your garden?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                dataStore.clearAll()
            }
        } message: {
            Text("This will remove all your carefully cultivated thoughts. They cannot be replanted once cleared.")
        }
        .onChange(of: dataStore.currentTheme) {
            dataStore.saveTheme()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                // Title
                HStack(spacing: 8) {
                    Text("Tree-e")
                        .font(.title2.bold())
                        .foregroundColor(currentTheme.textColor)
                    
                    if dataStore.trees.count > 1 {
                        Text("\(dataStore.trees.count)/5 trees")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(dataStore.trees.count >= 5 ? Color.red : currentTheme.borderColor)
                            .foregroundColor(dataStore.trees.count >= 5 ? .white : currentTheme.textColor)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 8) {
                    Button(action: { showAbout = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(currentTheme.textColor)
                            .padding(8)
                            .background(currentTheme.colorForLevel(0))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(currentTheme.borderColor, lineWidth: 1)
                            )
                    }
                    
                    Button(action: { showClearConfirm = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(currentTheme.textColor)
                            .padding(8)
                            .background(currentTheme.colorForLevel(0))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(currentTheme.borderColor, lineWidth: 1)
                            )
                    }
                    .disabled(dataStore.trees.allSatisfy { $0.nodes.isEmpty })
                    
                    // Theme button
                    Button(action: { showThemeDropdown.toggle() }) {
                        Image(systemName: "paintbrush")
                            .foregroundColor(currentTheme.textColor)
                            .padding(8)
                            .background(currentTheme.colorForLevel(0))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(currentTheme.borderColor, lineWidth: 1)
                            )
                    }
                    .overlay(
                        themeDropdownContent,
                        alignment: .topTrailing
                    )
                }
            }
            
            // Breadcrumb navigation
            if dataStore.trees.count > 1 {
                breadcrumbView
            }
        }
        .padding()
        .background(currentTheme.backgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(currentTheme.borderColor),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var themeDropdownContent: some View {
        if showThemeDropdown {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(Themes.all.keys.sorted()), id: \.self) { key in
                    Button(action: {
                        dataStore.currentTheme = key
                        showThemeDropdown = false
                    }) {
                        HStack {
                            Text(Themes.all[key]?.name ?? key)
                            Spacer()
                            if dataStore.currentTheme == key {
                                Image(systemName: "checkmark")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundColor(currentTheme.textColor)
                    }
                    .background(currentTheme.backgroundColor)
                }
            }
            .background(currentTheme.backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(currentTheme.borderColor, lineWidth: 1)
            )
            .shadow(radius: 4)
            .offset(x: -100, y: 40)
        }
    }
    
    // MARK: - Breadcrumb View
    private var breadcrumbView: some View {
        HStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    Button("Main Tree") {
                        if let mainIndex = dataStore.trees.firstIndex(where: { $0.id == "main" }) {
                            dataStore.activeTreeIndex = mainIndex
                        }
                    }
                    .font(.caption.monospaced())
                    .foregroundColor(currentTree?.id == "main" ? currentTheme.textColor : currentTheme.textColor.opacity(0.6))
                    .underline(currentTree?.id == "main")
                    
                    if let tree = currentTree {
                        ForEach(Array(tree.breadcrumb.enumerated()), id: \.offset) { index, crumb in
                            Text("/")
                                .font(.caption.monospaced())
                                .foregroundColor(currentTheme.textColor.opacity(0.6))
                            
                            Text(crumb)
                                .font(.caption.monospaced())
                                .foregroundColor(currentTheme.textColor.opacity(0.6))
                        }
                        
                        if tree.id != "main" {
                            Text("/")
                                .font(.caption.monospaced())
                                .foregroundColor(currentTheme.textColor.opacity(0.6))
                            
                            Text(tree.title)
                                .font(.caption.monospaced())
                                .foregroundColor(currentTheme.textColor)
                                .underline()
                        }
                    }
                }
            }
            
            Spacer()
            
            if let tree = currentTree, tree.id != "main" {
                Button("✓ Close") {
                    dataStore.closeTree(treeIndex: dataStore.activeTreeIndex)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(4)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Main Content View
    private var mainContentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if filteredNodes.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredNodes) { node in
                        nodeView(for: node)
                    }
                }
            }
            .padding()
        }
        .background(currentTheme.backgroundColor)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Text("🌱")
                .font(.system(size: 48))
            
            Text("Empty tree")
                .font(.title3.bold())
                .foregroundColor(currentTheme.textColor)
            
            Text(currentTree?.id == "main" ? "Start your Tree-e by adding your first thought below." : "This branch is ready for new ideas.")
                .font(.caption)
                .foregroundColor(currentTheme.textColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
    
    private func nodeView(for node: TreeNode) -> some View {
        Group {
            if editingNodeId == node.id {
                editingNodeView(for: node)
            } else {
                NodeView(
                    node: node,
                    theme: currentTheme,
                    isSelected: selectedNodeId == node.id,
                    treesLength: dataStore.trees.count,
                    isBranchedOut: dataStore.isNodeBranchedOut(node.id),
                    onTap: {
                        if selectedNodeId == node.id {
                            selectedNodeId = nil
                            if let lastNode = currentTree?.nodes.last {
                                currentIndentLevel = lastNode.level
                            } else {
                                currentIndentLevel = 0
                            }
                        } else {
                            selectedNodeId = node.id
                            currentIndentLevel = node.level + 1
                        }
                    },
                    onEdit: {
                        if !dataStore.isNodeBranchedOut(node.id) {
                            editingNodeId = node.id
                            editText = node.content
                        }
                    },
                    onToggleTask: {
                        dataStore.updateNode(nodeId: node.id, inTreeIndex: dataStore.activeTreeIndex) { updatedNode in
                            updatedNode.isTask.toggle()
                            updatedNode.isCompleted = false
                        }
                        selectedNodeId = nil
                    },
                    onToggleComplete: {
                        dataStore.updateNode(nodeId: node.id, inTreeIndex: dataStore.activeTreeIndex) { updatedNode in
                            updatedNode.isCompleted.toggle()
                        }
                    },
                    onFocus: {
                        focusedNode = node
                        selectedNodeId = nil
                    },
                    onBranchOut: {
                        if dataStore.trees.count < 5 && !dataStore.isNodeBranchedOut(node.id) {
                            dataStore.branchOut(nodeId: node.id, fromTreeIndex: dataStore.activeTreeIndex)
                            selectedNodeId = nil
                        }
                    },
                    onDelete: {
                        dataStore.deleteNode(nodeId: node.id, fromTreeIndex: dataStore.activeTreeIndex)
                        selectedNodeId = nil
                    },
                    onIndent: {
                        dataStore.updateNode(nodeId: node.id, inTreeIndex: dataStore.activeTreeIndex) { updatedNode in
                            updatedNode.level += 1
                        }
                        selectedNodeId = nil
                    },
                    onOutdent: {
                        dataStore.updateNode(nodeId: node.id, inTreeIndex: dataStore.activeTreeIndex) { updatedNode in
                            updatedNode.level = max(0, updatedNode.level - 1)
                        }
                        selectedNodeId = nil
                    }
                )
            }
        }
        .id(node.id)
    }
    
    private func editingNodeView(for node: TreeNode) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Indentation spacers
            ForEach(0..<node.level, id: \.self) { _ in
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 36)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                TextField("Edit node", text: $editText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isEditingFocused)
                    .onSubmit {
                        saveEdit(nodeId: node.id)
                    }
                    .onAppear {
                        isEditingFocused = true
                    }
                
                HStack(spacing: 8) {
                    Button("Save") {
                        saveEdit(nodeId: node.id)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    
                    Button("Cancel") {
                        cancelEdit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
        }
    }
    
    // MARK: - Input Area View
    private var inputAreaView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(">")
                    .font(.title2.monospaced())
                    .foregroundColor(currentTheme.promptColor)
                
                if currentIndentLevel > 0 {
                    Text(String(repeating: "  │", count: currentIndentLevel))
                        .font(.caption.monospaced())
                        .foregroundColor(currentTheme.promptColor.opacity(0.6))
                }
                
                TextField("Start typing...", text: $currentInput)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isInputFocused)
                    .onSubmit {
                        addNode()
                    }
                    .font(.system(size: 18, family: .monospaced))
                    .foregroundColor(currentTheme.textColor)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.x > 50 {
                                    currentIndentLevel += 1
                                } else if value.translation.x < -50 {
                                    currentIndentLevel = max(0, currentIndentLevel - 1)
                                }
                            }
                    )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(currentTheme.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(currentTheme.borderColor, lineWidth: 1)
                    )
            )
            
            if dataStore.trees.count <= 1 && (currentTree?.nodes.isEmpty ?? true) {
                Text("Tab to indent • Shift+Tab to outdent • Swipe on input to adjust level • Return to add node")
                    .font(.caption.monospaced())
                    .foregroundColor(currentTheme.textColor.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(currentTheme.backgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(currentTheme.borderColor),
            alignment: .top
        )
    }
    
    // MARK: - Helper Methods
    private func addNode() {
        let content = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        dataStore.addNode(
            content: content,
            toTreeIndex: dataStore.activeTreeIndex,
            afterNodeId: selectedNodeId,
            level: currentIndentLevel
        )
        
        currentInput = ""
    }
    
    private func saveEdit(nodeId: String) {
        let trimmedText = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            dataStore.updateNode(nodeId: nodeId, inTreeIndex: dataStore.activeTreeIndex) { updatedNode in
                updatedNode.content = trimmedText
            }
        }
        cancelEdit()
    }
    
    private func cancelEdit() {
        editingNodeId = nil
        editText = ""
        isEditingFocused = false
    }
}

// MARK: - About View

struct AboutView: View {
    let theme: AppTheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("The Philosophy")
                            .font(.title2.bold())
                            .foregroundColor(theme.textColor)
                        
                        Text("Tree-e embraces the power of simplicity and exploration. Like branches forming trees, individual thoughts combine to create complex ideas.")
                            .font(.body)
                            .foregroundColor(theme.textColor.opacity(0.9))
                            .lineSpacing(4)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Getting Started")
                            .font(.title2.bold())
                            .foregroundColor(theme.textColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach([
                                "• Start typing at the > prompt",
                                "• Swipe on input to adjust indent level", 
                                "• Tap nodes to access edit options",
                                "• Use Branch to explore thoughts in new trees",
                                "• Use Notes to add detailed information",
                                "• Your work auto-saves as you create"
                            ], id: \.self) { instruction in
                                Text(instruction)
                                    .font(.system(size: 14, family: .monospaced))
                                    .foregroundColor(theme.textColor.opacity(0.9))
                                    .lineSpacing(2)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(theme.backgroundColor)
            .navigationTitle("About Tree-e")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.textColor)
                }
            }
        }
    }
}

// MARK: - App Entry Point

@main
struct TreeEApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}