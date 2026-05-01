//
//  ContentView.swift
//  Youth Baseball AI
//
//  Created by Rich Morris on 4/28/26.
//

import SwiftUI
import UIKit
import Combine
internal import UniformTypeIdentifiers

// MARK: - Model

enum FieldPosition: String, CaseIterable, Identifiable, Codable {
    case pitcher = "P"
    case catcher = "C"
    case firstBase = "1B"
    case secondBase = "2B"
    case thirdBase = "3B"
    case shortstop = "SS"
    case leftField = "LF"
    case centerField = "CF"
    case rightField = "RF"

    var id: String { rawValue }

    static var autoAssignedPositions: [FieldPosition] {
        [.firstBase, .secondBase, .thirdBase, .shortstop, .leftField, .centerField, .rightField]
    }
}

enum PlayerStatus: String, CaseIterable, Codable {
    case active
    case injured
    case unavailable
    case guest
}

struct PlayerGameChangerStats: Codable, Equatable {
    var avg: String = ""
    var obp: String = ""
    var ops: String = ""
    var slg: String = ""
    var hits: String = ""
    var rbi: String = ""
    var runs: String = ""
    var walks: String = ""
    var strikeouts: String = ""

    var displayText: String {
        "Stats: AVG \(avg)  OBP \(obp)  OPS \(ops)  SLG \(slg)  H \(hits)  RBI \(rbi)  R \(runs)  BB \(walks)  SO \(strikeouts)"
    }
}

struct Player: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var number: String
    var cell: String
    var status: PlayerStatus
    var positionRatings: [FieldPosition: Int]
    var speedRating: Int
    var gameChangerStats: PlayerGameChangerStats?

    init(id: UUID = UUID(),
         name: String,
         number: String = "",
         cell: String = "",
         status: PlayerStatus = .active,
         positionRatings: [FieldPosition: Int] = [:],
         speedRating: Int = 1,
         gameChangerStats: PlayerGameChangerStats? = nil) {
        self.id = id
        self.name = name
        self.number = number
        self.cell = cell
        self.status = status
        self.positionRatings = positionRatings
        self.speedRating = speedRating
        self.gameChangerStats = gameChangerStats
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case number
        case cell
        case status
        case positionRatings
        case speedRating
        case gameChangerStats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        number = try container.decodeIfPresent(String.self, forKey: .number) ?? ""
        cell = try container.decodeIfPresent(String.self, forKey: .cell) ?? ""
        status = try container.decodeIfPresent(PlayerStatus.self, forKey: .status) ?? .active
        positionRatings = try container.decodeIfPresent([FieldPosition: Int].self, forKey: .positionRatings) ?? [:]
        speedRating = try container.decodeIfPresent(Int.self, forKey: .speedRating) ?? 1
        gameChangerStats = try container.decodeIfPresent(PlayerGameChangerStats.self, forKey: .gameChangerStats)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(number, forKey: .number)
        try container.encode(cell, forKey: .cell)
        try container.encode(status, forKey: .status)
        try container.encode(positionRatings, forKey: .positionRatings)
        try container.encode(speedRating, forKey: .speedRating)
        try container.encodeIfPresent(gameChangerStats, forKey: .gameChangerStats)
    }
}

struct Coach: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var number: String
    var cell: String

    init(id: UUID = UUID(), name: String, number: String = "", cell: String = "") {
        self.id = id
        self.name = name
        self.number = number
        self.cell = cell
    }
}



struct AppState: Codable {
    var players: [Player]
    var coaches: [Coach]?
    var pitcherID: UUID?
    var catcherID: UUID?
    var lineup: [FieldPosition: Player]
    var selectedInning: Int
    var inningLineups: [Int: [FieldPosition: Player]]
    var inningPitcherIDs: [Int: UUID]
    var inningCatcherIDs: [Int: UUID]
    var showRatingsOnField: Bool
    var showAssignedLineupTable: Bool
    var showFullNameAndNumber: Bool
    var showBenchOnField: Bool
    var showOnlyNineBattersAndDH: Bool
    var showSlowSpeedBattingWarnings: Bool
    var fallBallEnabled: Bool?
    var fallBallYouthEnabled: Bool?
    var battingOrderIDs: [UUID]
    var designatedHitterID: UUID?
    var designatedHitterForID: UUID?
    var selectedTeamIndex: Int?
    var teamNames: [String]?
    var teamSnapshots: [TeamSnapshot]?
}

struct TeamSnapshot: Codable {
    var players: [Player]
    var coaches: [Coach]?
    var pitcherID: UUID?
    var catcherID: UUID?
    var lineup: [FieldPosition: Player]
    var selectedInning: Int
    var inningLineups: [Int: [FieldPosition: Player]]
    var inningPitcherIDs: [Int: UUID]
    var inningCatcherIDs: [Int: UUID]
    var battingOrderIDs: [UUID]
    var designatedHitterID: UUID?
    var designatedHitterForID: UUID?
}



// MARK: - ViewModel

@MainActor
final class LineupViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var pitcherID: UUID?
    @Published var catcherID: UUID?
    @Published var lineup: [FieldPosition: Player] = [:]
    @Published var selectedInning = 1
    @Published var inningLineups: [Int: [FieldPosition: Player]] = [:]
    @Published var inningPitcherIDs: [Int: UUID] = [:]
    @Published var inningCatcherIDs: [Int: UUID] = [:]
    @Published var showRatingsOnField = true { didSet { save() } }
    @Published var showAssignedLineupTable = true { didSet { save() } }
    // true = full name and number. false = first initial, last name, and number.
    @Published var showFullNameAndNumber = true { didSet { save() } }
    @Published var showBenchOnField = true { didSet { save() } }
    @Published var showOnlyNineBattersAndDH = false { didSet { save() } }
    @Published var showSlowSpeedBattingWarnings = true { didSet { save() } }
    @Published var fallBallEnabled = false {
        didSet {
            if !fallBallEnabled {
                fallBallYouthEnabled = false
            }
            save()
        }
    }
    @Published var fallBallYouthEnabled = false { didSet { save() } }
    @Published var battingOrderIDs: [UUID] = [] { didSet { save() } }
    @Published var designatedHitterID: UUID? { didSet { save() } }
    @Published var designatedHitterForID: UUID? { didSet { save() } }
    @Published var selectedTeamIndex = 0
    @Published var teamNames = ["Team 1", "Team 2"] { didSet { save() } }
    // Removed GameChanger properties

    private var teamSnapshots: [TeamSnapshot?] = [nil, nil]
    private var isApplyingSavedState = false

    private let saveKey = "YouthPositionRanker.appState.v3"

    init() {
        load()
    }

    var selectedTeamName: String {
        guard teamNames.indices.contains(selectedTeamIndex) else { return "Team \(selectedTeamIndex + 1)" }
        return teamNames[selectedTeamIndex]
    }

    func selectTeam(_ index: Int) {
        let safeIndex = min(max(index, 0), 1)
        guard safeIndex != selectedTeamIndex else { return }

        teamSnapshots[selectedTeamIndex] = currentTeamSnapshot()
        selectedTeamIndex = safeIndex

        if let snapshot = teamSnapshots[safeIndex] {
            applyTeamSnapshot(snapshot)
        } else {
            applyTeamSnapshot(emptyTeamSnapshot())
        }

        save()
    }

    func updateSelectedTeamName(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, teamNames.indices.contains(selectedTeamIndex) else { return }
        teamNames[selectedTeamIndex] = trimmed
        save()
    }

    private func emptyTeamSnapshot() -> TeamSnapshot {
        TeamSnapshot(
            players: [],
            pitcherID: nil,
            catcherID: nil,
            lineup: [:],
            selectedInning: 1,
            inningLineups: [:],
            inningPitcherIDs: [:],
            inningCatcherIDs: [:],
            battingOrderIDs: [],
            designatedHitterID: nil,
            designatedHitterForID: nil
        )
    }

    private func currentTeamSnapshot() -> TeamSnapshot {
        saveCurrentInningState()
        return TeamSnapshot(
            players: players,
            pitcherID: pitcherID,
            catcherID: catcherID,
            lineup: lineup,
            selectedInning: selectedInning,
            inningLineups: inningLineups,
            inningPitcherIDs: inningPitcherIDs,
            inningCatcherIDs: inningCatcherIDs,
            battingOrderIDs: battingOrderIDs,
            designatedHitterID: designatedHitterID,
            designatedHitterForID: designatedHitterForID
        )
    }

    private func applyTeamSnapshot(_ snapshot: TeamSnapshot) {
        players = snapshot.players
        pitcherID = snapshot.pitcherID
        catcherID = snapshot.catcherID
        lineup = snapshot.lineup
        selectedInning = min(max(snapshot.selectedInning, 1), 7)
        inningLineups = snapshot.inningLineups
        inningPitcherIDs = snapshot.inningPitcherIDs
        inningCatcherIDs = snapshot.inningCatcherIDs
        battingOrderIDs = snapshot.battingOrderIDs
        designatedHitterID = snapshot.designatedHitterID
        designatedHitterForID = snapshot.designatedHitterForID

        if inningLineups[selectedInning] == nil {
            inningLineups[selectedInning] = lineup
        } else {
            lineup = inningLineups[selectedInning] ?? [:]
        }

        pitcherID = inningPitcherIDs[selectedInning] ?? snapshot.pitcherID
        catcherID = inningCatcherIDs[selectedInning] ?? snapshot.catcherID
        syncBattingOrder()
    }

    func addPlayer(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let player = Player(name: trimmed)
        players.append(player)
        battingOrderIDs.append(player.id)
        save()
    }

    func deletePlayers(at offsets: IndexSet) {
        let deletedIDs = offsets.map { players[$0].id }
        players.remove(atOffsets: offsets)

        battingOrderIDs.removeAll { deletedIDs.contains($0) }
        if let designatedHitterID, deletedIDs.contains(designatedHitterID) { self.designatedHitterID = nil }
        if let designatedHitterForID, deletedIDs.contains(designatedHitterForID) { self.designatedHitterForID = nil }

        if let pitcherID, deletedIDs.contains(pitcherID) { self.pitcherID = nil }
        if let catcherID, deletedIDs.contains(catcherID) { self.catcherID = nil }

        lineup = lineup.filter { !deletedIDs.contains($0.value.id) }
        for inning in inningLineups.keys {
            inningLineups[inning] = inningLineups[inning]?.filter { !deletedIDs.contains($0.value.id) } ?? [:]
        }
        for inning in inningPitcherIDs.keys where deletedIDs.contains(inningPitcherIDs[inning]!) {
            inningPitcherIDs.removeValue(forKey: inning)
        }
        for inning in inningCatcherIDs.keys where deletedIDs.contains(inningCatcherIDs[inning]!) {
            inningCatcherIDs.removeValue(forKey: inning)
        }
        save()
    }

    func deletePlayer(playerID: UUID) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        deletePlayers(at: IndexSet(integer: index))
    }

    func renamePlayer(playerID: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = players.firstIndex(where: { $0.id == playerID }) else { return }

        players[index].name = trimmed
        save()
    }

    func updatePlayerNumber(playerID: UUID, newNumber: String) {
        let trimmed = newNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }

        players[index].number = trimmed
        save()
    }
    
    func updatePlayerCell(playerID: UUID, newCell: String) {

        let trimmedCell = newCell.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }

        players[index].cell = trimmedCell

        save()

    }

    func updatePlayerSpeed(playerID: UUID, speedRating: Int) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[index].speedRating = speedRating
        save()
    }


    func setPlayerStatus(playerID: UUID, status: PlayerStatus) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[index].status = status

        if status != .active {
            lineup = lineup.filter { $0.value.id != playerID }

            for inning in inningLineups.keys {
                inningLineups[inning] = inningLineups[inning]?.filter { $0.value.id != playerID } ?? [:]
            }

            if pitcherID == playerID { pitcherID = nil }
            if catcherID == playerID { catcherID = nil }

            for inning in inningPitcherIDs.keys where inningPitcherIDs[inning] == playerID {
                inningPitcherIDs.removeValue(forKey: inning)
            }

            for inning in inningCatcherIDs.keys where inningCatcherIDs[inning] == playerID {
                inningCatcherIDs.removeValue(forKey: inning)
            }

            if designatedHitterID == playerID { designatedHitterID = nil }
            if designatedHitterForID == playerID { designatedHitterForID = nil }
        }

        saveCurrentInningState()
        save()
    }

    var activePlayers: [Player] {
        players.filter { $0.status == .active }
    }


    func setRating(playerID: UUID, position: FieldPosition, rating: Int) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[index].positionRatings[position] = rating
        save()
    }

    func removePosition(playerID: UUID, position: FieldPosition) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[index].positionRatings.removeValue(forKey: position)
        save()
    }

    func assignLineup() {
        if fallBallEnabled {
            assignFallBallLineups()
            return
        }

        var assignments: [FieldPosition: Player] = [:]
        var usedPlayerIDs = Set<UUID>()
        let eligiblePlayers = activePlayers

        if let pitcher = eligiblePlayers.first(where: { $0.id == pitcherID }) {
            assignments[.pitcher] = pitcher
            usedPlayerIDs.insert(pitcher.id)
        }

        if let catcher = eligiblePlayers.first(where: { $0.id == catcherID }), !usedPlayerIDs.contains(catcher.id) {
            assignments[.catcher] = catcher
            usedPlayerIDs.insert(catcher.id)
        }

        // Fills the remaining field positions using the best available rating.
        // 1 is best, 5 is worst.
        // Players are only considered for positions entered on their profile.
        for position in FieldPosition.autoAssignedPositions {
            let bestAvailable = eligiblePlayers
                .filter { player in
                    !usedPlayerIDs.contains(player.id) && player.positionRatings[position] != nil
                }
                .sorted { lhs, rhs in
                    let lhsRating = lhs.positionRatings[position] ?? 99
                    let rhsRating = rhs.positionRatings[position] ?? 99

                    if lhsRating == rhsRating {
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }

                    return lhsRating < rhsRating
                }
                .first

            if let bestAvailable {
                assignments[position] = bestAvailable
                usedPlayerIDs.insert(bestAvailable.id)
            }
        }

        lineup = assignments
        saveCurrentInningState()
        copyCurrentInningForwardIfNeeded()
        save()
    }

    private func assignFallBallLineups() {
        guard !activePlayers.isEmpty else { return }

        var playCounts = Dictionary(uniqueKeysWithValues: activePlayers.map { ($0.id, 0) })
        var benchCounts = Dictionary(uniqueKeysWithValues: activePlayers.map { ($0.id, 0) })
        var generatedLineups: [Int: [FieldPosition: Player]] = [:]
        var generatedPitchers: [Int: UUID] = [:]
        var generatedCatchers: [Int: UUID] = [:]
        var usedFallBallPitcherIDs = Set<UUID>()

        for inning in 1...7 {
            let assignment = fallBallYouthEnabled
                ? randomYouthFallBallAssignment(playCounts: &playCounts, benchCounts: &benchCounts)
                : randomFallBallAssignment(playCounts: &playCounts, benchCounts: &benchCounts, usedPitcherIDs: &usedFallBallPitcherIDs)

            generatedLineups[inning] = assignment

            if let pitcher = assignment[.pitcher] {
                generatedPitchers[inning] = pitcher.id
            }

            if let catcher = assignment[.catcher] {
                generatedCatchers[inning] = catcher.id
            }
        }

        inningLineups = generatedLineups
        inningPitcherIDs = generatedPitchers
        inningCatcherIDs = generatedCatchers
        selectedInning = 1
        lineup = generatedLineups[1] ?? [:]
        pitcherID = generatedPitchers[1]
        catcherID = fallBallYouthEnabled ? generatedCatchers[1] : catcherID
        save()
    }

    private func randomFallBallAssignment(playCounts: inout [UUID: Int], benchCounts: inout [UUID: Int], usedPitcherIDs: inout Set<UUID>) -> [FieldPosition: Player] {
        var assignments: [FieldPosition: Player] = [:]
        var usedPlayerIDs = Set<UUID>()
        let eligiblePlayers = activePlayers

        let availablePitchers = eligiblePlayers.filter { $0.positionRatings[.pitcher] != nil }
        let pitcherCandidates = availablePitchers.filter { !usedPitcherIDs.contains($0.id) }
        let selectedPitcher = (pitcherCandidates.isEmpty ? availablePitchers : pitcherCandidates)
            .shuffled()
            .sorted { lhs, rhs in
                playCounts[lhs.id, default: 0] < playCounts[rhs.id, default: 0]
            }
            .first

        if let pitcher = selectedPitcher {
            assignments[.pitcher] = pitcher
            usedPlayerIDs.insert(pitcher.id)
            usedPitcherIDs.insert(pitcher.id)
            playCounts[pitcher.id, default: 0] += 1
        }

        if let catcher = eligiblePlayers.first(where: { $0.id == catcherID }), !usedPlayerIDs.contains(catcher.id) {
            assignments[.catcher] = catcher
            usedPlayerIDs.insert(catcher.id)
            playCounts[catcher.id, default: 0] += 1
        }

        for position in FieldPosition.autoAssignedPositions.shuffled() {
            let candidates = eligiblePlayers
                .filter { player in
                    !usedPlayerIDs.contains(player.id) && player.positionRatings[position] != nil
                }
                .sorted { lhs, rhs in
                    let lhsPlays = playCounts[lhs.id, default: 0]
                    let rhsPlays = playCounts[rhs.id, default: 0]

                    if lhsPlays == rhsPlays {
                        return Bool.random()
                    }

                    return lhsPlays < rhsPlays
                }

            if let selectedPlayer = candidates.first {
                assignments[position] = selectedPlayer
                usedPlayerIDs.insert(selectedPlayer.id)
                playCounts[selectedPlayer.id, default: 0] += 1
            }
        }

        updateBenchCounts(usedPlayerIDs: usedPlayerIDs, benchCounts: &benchCounts)
        return assignments
    }

    private func randomYouthFallBallAssignment(playCounts: inout [UUID: Int], benchCounts: inout [UUID: Int]) -> [FieldPosition: Player] {
        var assignments: [FieldPosition: Player] = [:]
        var usedPlayerIDs = Set<UUID>()
        let eligiblePlayers = activePlayers

        for position in FieldPosition.allCases.shuffled() {
            let candidates = eligiblePlayers
                .filter { !usedPlayerIDs.contains($0.id) }
                .sorted { lhs, rhs in
                    let lhsPlays = playCounts[lhs.id, default: 0]
                    let rhsPlays = playCounts[rhs.id, default: 0]

                    if lhsPlays == rhsPlays {
                        return Bool.random()
                    }

                    return lhsPlays < rhsPlays
                }

            if let selectedPlayer = candidates.first {
                assignments[position] = selectedPlayer
                usedPlayerIDs.insert(selectedPlayer.id)
                playCounts[selectedPlayer.id, default: 0] += 1
            }
        }

        updateBenchCounts(usedPlayerIDs: usedPlayerIDs, benchCounts: &benchCounts)
        return assignments
    }

    private func updateBenchCounts(usedPlayerIDs: Set<UUID>, benchCounts: inout [UUID: Int]) {
        for player in activePlayers where !usedPlayerIDs.contains(player.id) {
            benchCounts[player.id, default: 0] += 1
        }
    }

    func clearInning() {
        lineup = [:]
        pitcherID = nil
        catcherID = nil
        inningLineups[selectedInning] = [:]
        inningPitcherIDs.removeValue(forKey: selectedInning)
        inningCatcherIDs.removeValue(forKey: selectedInning)
        save()
    }

    func clearAllInnings() {
        lineup = [:]
        pitcherID = nil
        catcherID = nil
        inningLineups = [:]
        inningPitcherIDs = [:]
        inningCatcherIDs = [:]
        save()
    }

    func deleteAllPlayerData() {
        players = []
        battingOrderIDs = []
        pitcherID = nil
        catcherID = nil
        lineup = [:]
        inningLineups = [:]
        inningPitcherIDs = [:]
        inningCatcherIDs = [:]
        designatedHitterID = nil
        designatedHitterForID = nil
        save()
    }

    func setCurrentLineupForAllInnings() {
        saveCurrentInningState()

        for inning in 1...9 {
            inningLineups[inning] = lineup

            if let pitcherID {
                inningPitcherIDs[inning] = pitcherID
            } else {
                inningPitcherIDs.removeValue(forKey: inning)
            }

            if let catcherID {
                inningCatcherIDs[inning] = catcherID
            } else {
                inningCatcherIDs.removeValue(forKey: inning)
            }
        }

        save()
    }

    func selectInning(_ inning: Int) {
        saveCurrentInningState()
        selectedInning = min(max(inning, 1), 9)

        if inningLineups[selectedInning] == nil, selectedInning > 1 {
            inningLineups[selectedInning] = inningLineups[selectedInning - 1] ?? lineup
            inningPitcherIDs[selectedInning] = inningPitcherIDs[selectedInning - 1]
            inningCatcherIDs[selectedInning] = inningCatcherIDs[selectedInning - 1]
        }

        lineup = inningLineups[selectedInning] ?? [:]
        pitcherID = inningPitcherIDs[selectedInning]
        catcherID = inningCatcherIDs[selectedInning]
        save()
    }

    func saveCurrentInningState() {
        inningLineups[selectedInning] = lineup

        if let pitcherID {
            inningPitcherIDs[selectedInning] = pitcherID
        } else {
            inningPitcherIDs.removeValue(forKey: selectedInning)
        }

        if let catcherID {
            inningCatcherIDs[selectedInning] = catcherID
        } else {
            inningCatcherIDs.removeValue(forKey: selectedInning)
        }
    }

    func updatePitcher(_ playerID: UUID?) {
        pitcherID = playerID
        if catcherID == playerID { catcherID = nil }
        saveCurrentInningState()
        copyCurrentInningForwardIfNeeded()
        save()
    }

    func updateCatcher(_ playerID: UUID?) {
        catcherID = playerID
        if pitcherID == playerID { pitcherID = nil }
        saveCurrentInningState()
        copyCurrentInningForwardIfNeeded()
        save()
    }

    func updateFieldPosition(_ position: FieldPosition, playerID: UUID?) {
        if position == .pitcher {
            updatePitcher(playerID)
            if let playerID, let player = activePlayers.first(where: { $0.id == playerID }) {
                lineup[.pitcher] = player
            } else {
                lineup.removeValue(forKey: .pitcher)
            }
            saveCurrentInningState()
            copyCurrentInningForwardIfNeeded()
            save()
            return
        }

        if position == .catcher {
            updateCatcher(playerID)
            if let playerID, let player = activePlayers.first(where: { $0.id == playerID }) {
                lineup[.catcher] = player
            } else {
                lineup.removeValue(forKey: .catcher)
            }
            saveCurrentInningState()
            copyCurrentInningForwardIfNeeded()
            save()
            return
        }

        if let playerID {
            guard let player = activePlayers.first(where: { $0.id == playerID }) else { return }

            lineup = lineup.filter { existingPosition, existingPlayer in
                existingPosition == position || existingPlayer.id != playerID
            }
            lineup[position] = player
        } else {
            lineup.removeValue(forKey: position)
        }

        saveCurrentInningState()
        copyCurrentInningForwardIfNeeded()
        save()
    }

    /// Places a bench player into the field in the best open/rated position.
    func placeBenchPlayerInField(playerID: UUID) {
        guard let player = activePlayers.first(where: { $0.id == playerID }) else { return }

        lineup = lineup.filter { _, existingPlayer in
            existingPlayer.id != playerID
        }

        let ratedPositions = FieldPosition.autoAssignedPositions
            .filter { player.positionRatings[$0] != nil }
            .sorted { lhs, rhs in
                let lhsRating = player.positionRatings[lhs] ?? 99
                let rhsRating = player.positionRatings[rhs] ?? 99

                if lhsRating == rhsRating {
                    return lhs.rawValue < rhs.rawValue
                }

                return lhsRating < rhsRating
            }

        if let openRatedPosition = ratedPositions.first(where: { lineup[$0] == nil }) {
            lineup[openRatedPosition] = player
        } else if let bestRatedPosition = ratedPositions.first {
            lineup[bestRatedPosition] = player
        } else if let openPosition = FieldPosition.autoAssignedPositions.first(where: { lineup[$0] == nil }) {
            lineup[openPosition] = player
        } else if let fallbackPosition = FieldPosition.autoAssignedPositions.first {
            lineup[fallbackPosition] = player
        }

        saveCurrentInningState()
        copyCurrentInningForwardIfNeeded()
        save()
    }

    func copyCurrentInningForwardIfNeeded() {
        guard selectedInning < 9 else { return }

        for inning in (selectedInning + 1)...9 {
            if inningLineups[inning] == nil || inningLineups[inning]?.isEmpty == true {
                inningLineups[inning] = lineup
                inningPitcherIDs[inning] = pitcherID
                inningCatcherIDs[inning] = catcherID
            }
        }
    }

    func player(for id: UUID) -> Player? {
        players.first { $0.id == id }
    }

    func displayLabel(for player: Player) -> String {
        let nameParts = player.name.split(separator: " ").map(String.init)
        let lastName = nameParts.last ?? player.name
        let firstInitial = nameParts.first?.first.map { "\($0)." } ?? ""
        let initialLastName = firstInitial.isEmpty ? lastName : "\(firstInitial) \(lastName)"

        if showFullNameAndNumber {
            return player.number.isEmpty ? player.name : "#\(player.number) \(player.name)"
        }

        return player.number.isEmpty ? initialLastName : "#\(player.number) \(initialLastName)"
    }

    func syncBattingOrder() {
        let existingIDs = Set(players.map { $0.id })
        battingOrderIDs.removeAll { !existingIDs.contains($0) }

        for player in players where !battingOrderIDs.contains(player.id) {
            battingOrderIDs.append(player.id)
        }
        save()
    }

    func moveBatters(from source: IndexSet, to destination: Int) {
        syncBattingOrder()
        battingOrderIDs.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func currentAppState() -> AppState {
        teamSnapshots[selectedTeamIndex] = currentTeamSnapshot()
        let savedSnapshots = teamSnapshots.enumerated().map { index, snapshot in
            snapshot ?? emptyTeamSnapshot()
        }

        return AppState(
            players: players,
            pitcherID: pitcherID,
            catcherID: catcherID,
            lineup: lineup,
            selectedInning: selectedInning,
            inningLineups: inningLineups,
            inningPitcherIDs: inningPitcherIDs,
            inningCatcherIDs: inningCatcherIDs,
            showRatingsOnField: showRatingsOnField,
            showAssignedLineupTable: showAssignedLineupTable,
            showFullNameAndNumber: showFullNameAndNumber,
            showBenchOnField: showBenchOnField,
            showOnlyNineBattersAndDH: showOnlyNineBattersAndDH,
            showSlowSpeedBattingWarnings: showSlowSpeedBattingWarnings,
            fallBallEnabled: fallBallEnabled,
            fallBallYouthEnabled: fallBallYouthEnabled,
            battingOrderIDs: battingOrderIDs,
            designatedHitterID: designatedHitterID,
            designatedHitterForID: designatedHitterForID,
            selectedTeamIndex: selectedTeamIndex,
            teamNames: teamNames,
            teamSnapshots: savedSnapshots
        )
    }

    private func applyAppState(_ state: AppState) {
        if let savedNames = state.teamNames, savedNames.count >= 2 {
            teamNames = Array(savedNames.prefix(2))
        }

        selectedTeamIndex = min(max(state.selectedTeamIndex ?? 0, 0), 1)

        if let savedSnapshots = state.teamSnapshots, savedSnapshots.count >= 2 {
            teamSnapshots = [savedSnapshots[0], savedSnapshots[1]]
            applyTeamSnapshot(savedSnapshots[selectedTeamIndex])
        } else {
            let legacySnapshot = TeamSnapshot(
                players: state.players,
                pitcherID: state.pitcherID,
                catcherID: state.catcherID,
                lineup: state.lineup,
                selectedInning: state.selectedInning,
                inningLineups: state.inningLineups,
                inningPitcherIDs: state.inningPitcherIDs,
                inningCatcherIDs: state.inningCatcherIDs,
                battingOrderIDs: state.battingOrderIDs,
                designatedHitterID: state.designatedHitterID,
                designatedHitterForID: state.designatedHitterForID
            )
            teamSnapshots = [legacySnapshot, emptyTeamSnapshot()]
            applyTeamSnapshot(legacySnapshot)
        }

        showRatingsOnField = state.showRatingsOnField
        showAssignedLineupTable = state.showAssignedLineupTable
        showFullNameAndNumber = state.showFullNameAndNumber
        showBenchOnField = state.showBenchOnField
        showOnlyNineBattersAndDH = state.showOnlyNineBattersAndDH
        showSlowSpeedBattingWarnings = state.showSlowSpeedBattingWarnings
        fallBallEnabled = state.fallBallEnabled ?? false
        fallBallYouthEnabled = fallBallEnabled ? (state.fallBallYouthEnabled ?? false) : false
    }

    // MARK: - Export Helper Methods (Omit GameChanger Stats)

    private func playerWithoutGameChangerStats(_ player: Player) -> Player {
        var copy = player
        copy.gameChangerStats = nil
        return copy
    }

    private func lineupWithoutGameChangerStats(_ lineup: [FieldPosition: Player]) -> [FieldPosition: Player] {
        Dictionary(uniqueKeysWithValues: lineup.map { position, player in
            (position, playerWithoutGameChangerStats(player))
        })
    }

    private func inningLineupsWithoutGameChangerStats(_ lineups: [Int: [FieldPosition: Player]]) -> [Int: [FieldPosition: Player]] {
        Dictionary(uniqueKeysWithValues: lineups.map { inning, lineup in
            (inning, lineupWithoutGameChangerStats(lineup))
        })
    }

    private func teamSnapshotWithoutGameChangerStats(_ snapshot: TeamSnapshot) -> TeamSnapshot {
        TeamSnapshot(
            players: snapshot.players.map { playerWithoutGameChangerStats($0) },
            pitcherID: snapshot.pitcherID,
            catcherID: snapshot.catcherID,
            lineup: lineupWithoutGameChangerStats(snapshot.lineup),
            selectedInning: snapshot.selectedInning,
            inningLineups: inningLineupsWithoutGameChangerStats(snapshot.inningLineups),
            inningPitcherIDs: snapshot.inningPitcherIDs,
            inningCatcherIDs: snapshot.inningCatcherIDs,
            battingOrderIDs: snapshot.battingOrderIDs,
            designatedHitterID: snapshot.designatedHitterID,
            designatedHitterForID: snapshot.designatedHitterForID
        )
    }

    func exportAppStateData() -> Data {
        var exportState = currentAppState()
        exportState.players = exportState.players.map { playerWithoutGameChangerStats($0) }
        exportState.lineup = lineupWithoutGameChangerStats(exportState.lineup)
        exportState.inningLineups = inningLineupsWithoutGameChangerStats(exportState.inningLineups)
        exportState.teamSnapshots = exportState.teamSnapshots?.map { teamSnapshotWithoutGameChangerStats($0) }

        do {
            return try JSONEncoder().encode(exportState)
        } catch {
            print("Failed to export app state: \(error)")
            return Data()
        }
    }

    func exportPlayerNameNumberData() -> Data {
        struct SharedPlayer: Codable {
            let name: String
            let number: String
        }

        let sharedPlayers = players.map { player in
            SharedPlayer(name: player.name, number: player.number)
        }

        do {
            return try JSONEncoder().encode(sharedPlayers)
        } catch {
            print("Failed to export player name and number data: \(error)")
            return Data()
        }
    }

    func importAppStateData(_ data: Data) throws {
        let state = try JSONDecoder().decode(AppState.self, from: data)
        applyAppState(state)
        save()
    }

    func importPlayerNameNumberData(_ data: Data) throws {
        struct SharedPlayer: Codable {
            let name: String
            let number: String
        }

        let sharedPlayers = try JSONDecoder().decode([SharedPlayer].self, from: data)

        for sharedPlayer in sharedPlayers {
            let trimmedName = sharedPlayer.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNumber = sharedPlayer.number.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedName.isEmpty else { continue }

            players.append(Player(name: trimmedName, number: trimmedNumber))
        }

        syncBattingOrder()
        save()
    }

    func importGameChangerStatsData(_ data: Data) throws -> Int {
        guard let rawString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
            throw NSError(domain: "GameChangerImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read GameChanger file."])
        }

        let rows = parseCSV(rawString)
        guard rows.count > 1 else {
            throw NSError(domain: "GameChangerImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "GameChanger file has no stat rows."])
        }

        guard let headerRowIndex = rows.firstIndex(where: { row in
            let normalizedRow = row.map { normalizeHeader($0) }
            return (normalizedRow.contains("first") && normalizedRow.contains("last")) || normalizedRow.contains("player") || normalizedRow.contains("name")
        }) else {
            throw NSError(domain: "GameChangerImport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not find GameChanger player header row."])
        }

        let header = rows[headerRowIndex]
        let statRows = rows.dropFirst(headerRowIndex + 1)
        let normalizedHeader = header.map { normalizeHeader($0) }

        func columnIndex(_ names: [String]) -> Int? {
            for name in names {
                if let index = normalizedHeader.firstIndex(of: normalizeHeader(name)) {
                    return index
                }
            }
            return nil
        }

        let numberIndex = columnIndex(["Number", "No", "#", "Jersey", "Jersey Number"])
        let playerIndex = columnIndex(["Player", "Name", "Player Name", "Athlete"])
        let firstNameIndex = columnIndex(["First", "First Name", "FirstName"])
        let lastNameIndex = columnIndex(["Last", "Last Name", "LastName"])
        let avgIndex = columnIndex(["AVG", "BA", "Batting Average", "Batting Avg"])
        let obpIndex = columnIndex(["OBP", "On Base Percentage", "On-Base Percentage"])
        let opsIndex = columnIndex(["OPS", "On Base Plus Slugging", "On-Base Plus Slugging"])
        let slgIndex = columnIndex(["SLG", "Slugging", "Slugging Percentage"])
        let hitsIndex = columnIndex(["H", "Hits"])
        let rbiIndex = columnIndex(["RBI", "RBIs", "Runs Batted In"])
        let runsIndex = columnIndex(["R", "Runs"])
        let walksIndex = columnIndex(["BB", "Walks", "Base on Balls"])
        let strikeoutsIndex = columnIndex(["SO", "K", "Strikeouts", "Strike Outs"])

        var importedStatsByName: [String: PlayerGameChangerStats] = [:]
        var importedStatsByNumber: [String: PlayerGameChangerStats] = [:]

        for row in statRows {
            let playerName: String
            if let playerIndex, row.indices.contains(playerIndex) {
                playerName = row[playerIndex]
            } else if let firstNameIndex, let lastNameIndex,
                      row.indices.contains(firstNameIndex), row.indices.contains(lastNameIndex) {
                playerName = "\(row[firstNameIndex]) \(row[lastNameIndex])"
            } else {
                continue
            }

            let normalizedName = normalizePlayerName(playerName)
            let normalizedNumber = value(from: row, at: numberIndex).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty || !normalizedNumber.isEmpty else { continue }

            let stats = PlayerGameChangerStats(
                avg: value(from: row, at: avgIndex),
                obp: value(from: row, at: obpIndex),
                ops: value(from: row, at: opsIndex),
                slg: value(from: row, at: slgIndex),
                hits: value(from: row, at: hitsIndex),
                rbi: value(from: row, at: rbiIndex),
                runs: value(from: row, at: runsIndex),
                walks: value(from: row, at: walksIndex),
                strikeouts: value(from: row, at: strikeoutsIndex)
            )

            if !normalizedName.isEmpty {
                importedStatsByName[normalizedName] = stats
            }

            if !normalizedNumber.isEmpty && normalizedNumber != "—" {
                importedStatsByNumber[normalizedNumber] = stats
            }
        }

        var matchCount = 0
        for index in players.indices {
            let normalizedName = normalizePlayerName(players[index].name)
            let normalizedNumber = players[index].number.trimmingCharacters(in: .whitespacesAndNewlines)

            if let stats = importedStatsByName[normalizedName] ?? importedStatsByNumber[normalizedNumber] {
                players[index].gameChangerStats = stats
                matchCount += 1
            }
        }

        save()
        return matchCount
    }

    func clearGameChangerStats() {
        for index in players.indices {
            players[index].gameChangerStats = nil
        }
        save()
    }

    // MARK: - Lineup Grid PDF Export
    func createLineupGridPDF() throws -> URL {
        saveCurrentInningState()

        let pageWidth: CGFloat = 792
        let pageHeight: CGFloat = 612
        let margin: CGFloat = 36
        let titleHeight: CGFloat = 42
        let headerHeight: CGFloat = 28
        let rowHeight: CGFloat = 26
        let orderColumnWidth: CGFloat = 42
        let nameColumnWidth: CGFloat = 190
        let inningColumnWidth = (pageWidth - (margin * 2) - orderColumnWidth - nameColumnWidth) / 9

        let orderedPlayers = battingOrderIDs
            .compactMap { player(for: $0) }
            .filter { $0.status == .active }

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeFileName(selectedTeamName))-Lineup.pdf")

        try renderer.writePDF(to: url) { context in
            var playerIndex = 0

            repeat {
                context.beginPage()

                drawPDFText(
                    selectedTeamName,
                    in: CGRect(x: margin, y: 22, width: pageWidth - margin * 2, height: 26),
                    font: .boldSystemFont(ofSize: 20),
                    alignment: .center
                )

                drawPDFText(
                    "Lineup Grid",
                    in: CGRect(x: margin, y: 48, width: pageWidth - margin * 2, height: 18),
                    font: .systemFont(ofSize: 12),
                    alignment: .center
                )

                var y = margin + titleHeight
                drawPDFCell("#", x: margin, y: y, width: orderColumnWidth, height: headerHeight, isHeader: true)
                drawPDFCell("Player", x: margin + orderColumnWidth, y: y, width: nameColumnWidth, height: headerHeight, isHeader: true)

                for inning in 1...9 {
                    let x = margin + orderColumnWidth + nameColumnWidth + CGFloat(inning - 1) * inningColumnWidth
                    drawPDFCell("\(inning)", x: x, y: y, width: inningColumnWidth, height: headerHeight, isHeader: true)
                }

                y += headerHeight

                while playerIndex < orderedPlayers.count && y + rowHeight <= pageHeight - margin {
                    let player = orderedPlayers[playerIndex]
                    drawPDFCell("\(playerIndex + 1)", x: margin, y: y, width: orderColumnWidth, height: rowHeight)
                    drawPDFCell(displayLabel(for: player), x: margin + orderColumnWidth, y: y, width: nameColumnWidth, height: rowHeight, alignment: .left)

                    for inning in 1...9 {
                        let inningLineup = inningLineups[inning] ?? [:]
                        let positionText = positionForPlayer(player, in: inningLineup)
                        let x = margin + orderColumnWidth + nameColumnWidth + CGFloat(inning - 1) * inningColumnWidth
                        drawPDFCell(positionText, x: x, y: y, width: inningColumnWidth, height: rowHeight)
                    }

                    y += rowHeight
                    playerIndex += 1
                }
            } while playerIndex < orderedPlayers.count
        }

        return url
    }

    private func positionForPlayer(_ player: Player, in inningLineup: [FieldPosition: Player]) -> String {
        if let position = inningLineup.first(where: { $0.value.id == player.id })?.key {
            return exportLabel(for: position)
        }
        return "X"
    }

    private func exportLabel(for position: FieldPosition) -> String {
        switch position {
        case .pitcher: return "P"
        case .catcher: return "C"
        case .firstBase: return "1st"
        case .secondBase: return "2nd"
        case .thirdBase: return "3rd"
        case .shortstop: return "SS"
        case .rightField: return "RF"
        case .centerField: return "CF"
        case .leftField: return "LF"
        }
    }

    private func drawPDFCell(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, isHeader: Bool = false, alignment: NSTextAlignment = .center) {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        (UIColor(named: "LaunchBackgroundBlack") ?? .black).setStroke()
        UIBezierPath(rect: rect).stroke()

        if isHeader {
            UIColor(white: 0.90, alpha: 1).setFill()
            UIBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
        }

        drawPDFText(
            text,
            in: rect.insetBy(dx: 5, dy: 5),
            font: isHeader ? .boldSystemFont(ofSize: 10) : .systemFont(ofSize: 9),
            alignment: alignment
        )
    }

    private func drawPDFText(_ text: String, in rect: CGRect, font: UIFont, alignment: NSTextAlignment) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: (UIColor(named: "LaunchBackgroundBlack") ?? .black),
            .paragraphStyle: paragraphStyle
        ]

        text.draw(in: rect, withAttributes: attributes)
    }

    private func safeFileName(_ value: String) -> String {
        value
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private func value(from row: [String], at index: Int?) -> String {
        guard let index, row.indices.contains(index) else { return "—" }
        let trimmed = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func normalizeHeader(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizePlayerName(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func csvEscapedValue(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }

    private func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        var iterator = Array(text).makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if insideQuotes, let nextCharacter = iterator.next() {
                    if nextCharacter == "\"" {
                        field.append("\"")
                    } else {
                        insideQuotes = false
                        if nextCharacter == "," {
                            row.append(field)
                            field = ""
                        } else if nextCharacter == "\n" {
                            row.append(field)
                            rows.append(row)
                            row = []
                            field = ""
                        } else if nextCharacter != "\r" {
                            field.append(nextCharacter)
                        }
                    }
                } else {
                    insideQuotes.toggle()
                }
            } else if character == ",", !insideQuotes {
                row.append(field)
                field = ""
            } else if character == "\n", !insideQuotes {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows.filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    }

    func save() {
        guard !isApplyingSavedState else { return }

        do {
            let data = try JSONEncoder().encode(currentAppState())
            UserDefaults.standard.set(data, forKey: saveKey)
        } catch {
            print("Failed to save app state: \(error)")
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }

        do {
            isApplyingSavedState = true
            defer { isApplyingSavedState = false }

            let state = try JSONDecoder().decode(AppState.self, from: data)
            applyAppState(state)
        } catch {
            isApplyingSavedState = false
            print("Failed to load app state: \(error)")
            UserDefaults.standard.set(data, forKey: "LineupChangerRecoveryBackup")
        }
    }
}

// MARK: - Main UI

struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            ContentView()

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.35)) {
                    showSplash = false
                }
            }
        }
    }
}

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("SplashScreen")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
    }
}

enum MainTab: Hashable {
    case field
    case lineup
    case players
    case settings
}

struct ContentView: View {
    @StateObject private var viewModel = LineupViewModel()
    @State private var selectedTab: MainTab = .field

    var body: some View {
        TabView(selection: $selectedTab) {
            AssignmentView(viewModel: viewModel)
                .tabItem {
                    Label("Field", systemImage: "baseball.diamond.bases")
                }
                .tag(MainTab.field)

            LineupOrderView(viewModel: viewModel)
                .tabItem {
                    Label("Lineup", systemImage: "list.number")
                }
                .tag(MainTab.lineup)

            PlayerListView(viewModel: viewModel)
                .tabItem {
                    Label("Players", systemImage: "person.3")
                }
                .tag(MainTab.players)

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(MainTab.settings)
        }
        .onAppear {
            selectedTab = viewModel.players.isEmpty ? .players : .field
        }
    }
}

// MARK: - Players Tab

struct TeamPickerView: View {
    @ObservedObject var viewModel: LineupViewModel

    var body: some View {
        Picker("Team", selection: Binding(
            get: { viewModel.selectedTeamIndex },
            set: { viewModel.selectTeam($0) }
        )) {
            Text(viewModel.teamNames.indices.contains(0) ? viewModel.teamNames[0] : "Team 1").tag(0)
            Text(viewModel.teamNames.indices.contains(1) ? viewModel.teamNames[1] : "Team 2").tag(1)
        }
        .pickerStyle(.segmented)
    }
}

struct TeamHeaderView: View {
    @ObservedObject var viewModel: LineupViewModel
    @Binding var editedTeamName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TeamPickerView(viewModel: viewModel)

            TextField("Team name", text: $editedTeamName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.updateSelectedTeamName(editedTeamName)
                }

            Button("Save Team Name") {
                viewModel.updateSelectedTeamName(editedTeamName)
            }
            .buttonStyle(.bordered)
        }
        .onChange(of: viewModel.selectedTeamIndex) { _, _ in
            editedTeamName = viewModel.selectedTeamName
        }
    }
}

struct PlayerListView: View {
    @ObservedObject var viewModel: LineupViewModel
    @State private var newPlayerName = ""
    @FocusState private var focusedField: PlayerListFocusedField?

    private enum PlayerListFocusedField {
        case newPlayer
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    TeamPickerView(viewModel: viewModel)
                    Text(viewModel.selectedTeamName)
                        .font(.headline)
                }
                .padding(.horizontal)
                .onChange(of: viewModel.selectedTeamIndex) { _, _ in
                    focusedField = nil
                }
                HStack {
                    TextField("Player name", text: $newPlayerName)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .newPlayer)
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.addPlayer(name: newPlayerName)
                            newPlayerName = ""
                            focusedField = nil
                        }

                    Button("Add") {
                        viewModel.addPlayer(name: newPlayerName)
                        newPlayerName = ""
                        focusedField = nil
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                List {
                    ForEach(viewModel.players.sorted { lhs, rhs in
                        let lhsNumber = Int(lhs.number)
                        let rhsNumber = Int(rhs.number)

                        switch (lhsNumber, rhsNumber) {
                        case let (l?, r?):
                            return l < r
                        case (nil, nil):
                            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                        case (nil, _?):
                            return false
                        case (_?, nil):
                            return true
                        }
                    }) { player in
                        NavigationLink {
                            PlayerDetailView(viewModel: viewModel, player: player)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(viewModel.displayLabel(for: player))
                                        .font(.headline)
                                    if player.status == .guest {
                                        Text("(Guest)")
                                            .font(.headline)
                                            .italic()
                                            .foregroundStyle(.red)
                                    }
                                }
                                
                                if !player.cell.filter({ $0.isNumber }).isEmpty {

                                    Menu(player.cell) {

                                        if let callURL = URL(string: "tel://\(player.cell.filter { $0.isNumber })") {

                                            Link("Call", destination: callURL)

                                        }

                                        if let textURL = URL(string: "sms:\(player.cell.filter { $0.isNumber })") {

                                            Link("Text", destination: textURL)

                                        }

                                    }

                                    .font(.caption)

                                }
                                
                                if player.status != .active && player.status != .guest {
                                    Text(player.status == .injured ? "Injured" : "Unavailable")
                                        .font(.caption)
                                        .foregroundStyle(player.status == .injured ? .red : .orange)
                                }

                                if player.positionRatings.isEmpty {
                                    Text("No positions added")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(positionSummary(for: player))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                viewModel.deletePlayer(playerID: player.id)
                            }

                            Button("Injured") {
                                viewModel.setPlayerStatus(playerID: player.id, status: .injured)
                            }
                            .tint(.red)

                            Button("Unavailable") {
                                viewModel.setPlayerStatus(playerID: player.id, status: .unavailable)
                            }
                            .tint(.red)

                            Button("Guest") {
                                viewModel.setPlayerStatus(playerID: player.id, status: .guest)
                            }
                            .tint(.red)

                            if player.status != .active {
                                Button("Active") {
                                    viewModel.setPlayerStatus(playerID: player.id, status: .active)
                                }
                                .tint(.red)
                            }
                        }
                    }
                    .onDelete(perform: viewModel.deletePlayers)
                }
            }
            .navigationTitle("Players")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        if focusedField == .newPlayer {
                            viewModel.addPlayer(name: newPlayerName)
                            newPlayerName = ""
                        }
                        focusedField = nil
                    }
                }
            }
        }
    }

    private func positionSummary(for player: Player) -> String {
        FieldPosition.allCases
            .compactMap { position in
                guard let rating = player.positionRatings[position] else { return nil }
                return "\(position.rawValue): \(rating)"
            }
            .joined(separator: " • ")
    }
}

// MARK: - Player Detail

struct PlayerDetailView: View {
    @ObservedObject var viewModel: LineupViewModel
    let player: Player

    @State private var editedName: String = ""
    @State private var editedNumber: String = ""
    @State private var editedCellNumber: String = ""
    @State private var selectedSpeedRating: Int = 1
    @State private var selectedPosition: FieldPosition = .firstBase
    @State private var selectedRating: Int = 1

    private var currentPlayer: Player? {
        viewModel.players.first(where: { $0.id == player.id })
    }

    var body: some View {
        Form {
            Section("Player") {
                TextField("Name", text: $editedName)
                    .onSubmit {
                        viewModel.renamePlayer(playerID: player.id, newName: editedName)
                    }

                TextField("Number", text: $editedNumber)
                    .keyboardType(.numberPad)
                    .onSubmit {
                        viewModel.updatePlayerNumber(playerID: player.id, newNumber: editedNumber)
                    }

                TextField("Cell #", text: $editedCellNumber)
                    .keyboardType(.numberPad)
                    .onChange(of: editedCellNumber) { _, newValue in
                        editedCellNumber = formatPhoneNumber(newValue)
                    }
                
                if !editedCellNumber.filter({ $0.isNumber }).isEmpty {
                    Menu("Contact \(editedCellNumber)") {
                        if let callURL = URL(string: "tel://\(editedCellNumber.filter { $0.isNumber })") {
                            Link("Call", destination: callURL)
                        }

                        if let textURL = URL(string: "sms:\(editedCellNumber.filter { $0.isNumber })") {
                            Link("Text", destination: textURL)
                        }
                    }
                }

                Picker("Steal Ability", selection: $selectedSpeedRating) {
                    Text("1 - Steal").tag(1)
                    Text("2 - No Steal").tag(2)
                }
                .pickerStyle(.segmented)

                Button("Save Player Info") {
                    viewModel.renamePlayer(playerID: player.id, newName: editedName)
                    viewModel.updatePlayerNumber(playerID: player.id, newNumber: editedNumber)
                    viewModel.updatePlayerCell(playerID: player.id, newCell: editedCellNumber)
                    viewModel.updatePlayerSpeed(playerID: player.id, speedRating: selectedSpeedRating)
                }
            }

            Section("Add or Update Position") {
                Picker("Position", selection: $selectedPosition) {
                    ForEach(FieldPosition.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }

                Picker("Rating", selection: $selectedRating) {
                    ForEach(1...5, id: \.self) { rating in
                        Text("\(rating)").tag(rating)
                    }
                }

                Button("Save Position Rating") {
                    viewModel.setRating(playerID: player.id, position: selectedPosition, rating: selectedRating)
                }
                .buttonStyle(.borderedProminent)

                if currentPlayer?.positionRatings[selectedPosition] != nil {
                    Button("Remove Selected Position", role: .destructive) {
                        viewModel.removePosition(playerID: player.id, position: selectedPosition)
                    }
                }
            }

            Section("Current Positions") {
                if let currentPlayer, currentPlayer.positionRatings.isEmpty {
                    Text("No positions added yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(FieldPosition.allCases) { position in
                        if let rating = currentPlayer?.positionRatings[position] {
                            HStack {
                                Text(position.rawValue)
                                    .fontWeight(.semibold)
                                Spacer()
                                Picker("Rating", selection: Binding(
                                    get: { rating },
                                    set: { newRating in
                                        viewModel.setRating(playerID: player.id, position: position, rating: newRating)
                                    }
                                )) {
                                    ForEach(1...5, id: \.self) { rating in
                                        Text("\(rating)").tag(rating)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .swipeActions {
                                Button("Remove", role: .destructive) {
                                    viewModel.removePosition(playerID: player.id, position: position)
                                }
                            }
                        }
                    }
                }
            }

            Section("Rating Scale") {
                Text("1 = best, 5 = worst. A player is only considered for positions listed here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(currentPlayer?.name ?? player.name)
        .onAppear {
            editedName = currentPlayer?.name ?? player.name
            editedNumber = currentPlayer?.number ?? player.number
            editedCellNumber = currentPlayer?.cell ?? player.cell
            selectedSpeedRating = currentPlayer?.speedRating ?? player.speedRating
        }
    }

    // Helper function for formatting phone number as (XXX)XXX-XXXX
    private func formatPhoneNumber(_ number: String) -> String {
        let digits = number.filter { $0.isNumber }
        var result = ""

        let limited = String(digits.prefix(10))

        for (index, digit) in limited.enumerated() {
            switch index {
            case 0:
                result += "("
                result.append(digit)
            case 2:
                result.append(digit)
                result += ")"
            case 3:
                result.append(digit)
            case 5:
                result.append(digit)
                result += "-"
            default:
                result.append(digit)
            }
        }

        return result
    }
}

// MARK: - Lineup Tab

struct AssignmentView: View {
    @ObservedObject var viewModel: LineupViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Team") {
                    TeamPickerView(viewModel: viewModel)
                    Text(viewModel.selectedTeamName)
                        .font(.headline)
                }
                Section("Inning") {
                    Picker("Inning", selection: Binding(
                        get: { viewModel.selectedInning },
                        set: { viewModel.selectInning($0) }
                    )) {
                        ForEach(1...9, id: \.self) { inning in
                            Text("\(inning)").tag(inning)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !viewModel.fallBallYouthEnabled {
                    Section("Manual Positions") {
                        if !viewModel.fallBallEnabled {
                            Picker("Pitcher", selection: Binding(
                                get: { viewModel.pitcherID },
                                set: { newValue in
                                    viewModel.updatePitcher(newValue)
                                }
                            )) {
                                Text("Choose pitcher").tag(UUID?.none)
                                ForEach(viewModel.activePlayers) { player in
                                    Text(player.name).tag(Optional(player.id))
                                }
                            }
                        }

                        Picker("Catcher", selection: Binding(
                            get: { viewModel.catcherID },
                            set: { newValue in
                                viewModel.updateCatcher(newValue)
                            }
                        )) {
                            Text("Choose catcher").tag(UUID?.none)
                            ForEach(viewModel.activePlayers) { player in
                                Text(player.name).tag(Optional(player.id))
                            }
                        }
                    }
                }

                Section {
                    Button(viewModel.fallBallEnabled ? "Generate Fall Ball Lineups" : "Auto-Fill Remaining Positions") {
                        viewModel.assignLineup()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear Inning", role: .destructive) {
                        viewModel.clearInning()
                    }

                    Button("Clear All Innings", role: .destructive) {
                        viewModel.clearAllInnings()
                    }

                    Button("Set Lineup for All Innings") {
                        viewModel.setCurrentLineupForAllInnings()
                    }
                }

                Section("Field View") {
                    BaseballFieldLineupView(
                        lineup: viewModel.lineup,
                        showRatings: viewModel.showRatingsOnField,
                        showFullNameAndNumber: viewModel.showFullNameAndNumber
                    )
                    .frame(height: 430)
                    .listRowInsets(EdgeInsets())
                }

                if viewModel.showAssignedLineupTable {
                    Section("Assigned Lineup") {
                        ForEach(FieldPosition.allCases) { position in
                            HStack {
                                Text(position.rawValue)
                                    .fontWeight(.semibold)
                                    .frame(width: 50, alignment: .leading)

                                Picker("", selection: Binding(
                                    get: { viewModel.lineup[position]?.id },
                                    set: { newPlayerID in
                                        viewModel.updateFieldPosition(position, playerID: newPlayerID)
                                    }
                                )) {
                                    Text("Unassigned").tag(UUID?.none)
                                    ForEach(viewModel.activePlayers) { player in
                                        Text(viewModel.displayLabel(for: player)).tag(Optional(player.id))
                                    }
                                }
                                .pickerStyle(.menu)

                                Spacer()

                                if let player = viewModel.lineup[position] {
                                    Text(ratingLabel(for: player, at: position))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if viewModel.showBenchOnField {
                    Section("Bench") {
                        let bench = benchPlayers()

                        if bench.isEmpty {
                            Text("No bench players")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(bench) { player in
                                HStack {
                                    HStack(spacing: 4) {
                                        Text(viewModel.displayLabel(for: player))
                                        if player.status == .guest {
                                            Text("(Guest)")
                                                .italic()
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    Spacer()

                                    Button("Put In Field") {
                                        viewModel.placeBenchPlayerInField(playerID: player.id)
                                    }
                                    .buttonStyle(.borderedProminent)

                                    Menu("Position") {
                                        ForEach(FieldPosition.autoAssignedPositions) { position in
                                            Button("Move to \(position.rawValue)") {
                                                viewModel.updateFieldPosition(position, playerID: player.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section("How assignment works") {
                    Text(viewModel.fallBallEnabled ? "Fall Ball generates all 9 innings at once and tries to share bench time evenly. Standard Fall Ball automatically uses a different pitcher each inning from players who have Pitcher listed on their profile, keeps catcher manual, then randomly assigns players only to positions listed on their profile. Youth mode randomly assigns all active players across every position, including pitcher and catcher." : "Each inning can have a different field lineup. When you set an inning, the app carries that lineup forward to later empty innings until you manually change or auto-fill those innings. Pitcher and catcher are selected manually. The app fills 1B, 2B, 3B, SS, LF, CF, and RF using the best available rating.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Field")
        }
    }

    private func benchPlayers() -> [Player] {
        let assignedIDs = Set(viewModel.lineup.values.map { $0.id })
        return viewModel.activePlayers.filter { !assignedIDs.contains($0.id) }
    }

    private func displayName(for position: FieldPosition) -> String {
        switch position {
        case .pitcher: return "Pitcher (P)"
        case .catcher: return "Catcher (C)"
        case .firstBase: return "First Base (1B)"
        case .secondBase: return "Second Base (2B)"
        case .thirdBase: return "Third Base (3B)"
        case .shortstop: return "Shortstop (SS)"
        case .leftField: return "Left Field (LF)"
        case .centerField: return "Center Field (CF)"
        case .rightField: return "Right Field (RF)"
        }
    }

    private func ratingLabel(for player: Player, at position: FieldPosition) -> String {
        guard let rating = player.positionRatings[position] else { return "Manual" }
        return "Rating \(rating)"
    }
}


// MARK: - Baseball Field View


// MARK: - Lineup / Batting Order Tab

struct LineupOrderView: View {
    @ObservedObject var viewModel: LineupViewModel
    @State private var isShowingLineupShareSheet = false
    @State private var lineupPDFURL: URL?
    @State private var lineupExportMessage = ""

    private var orderedPlayers: [Player] {
        viewModel.battingOrderIDs
            .compactMap { viewModel.player(for: $0) }
            .filter { $0.status == .active }
    }

    private var displayedBatters: [Player] {
        if viewModel.showOnlyNineBattersAndDH {
            return Array(orderedPlayers.prefix(9))
        }

        return orderedPlayers
    }

    private func hasSlowPitcherCatcherWarning(at index: Int) -> Bool {
        guard viewModel.showSlowSpeedBattingWarnings,
              index > 0,
              displayedBatters.indices.contains(index),
              displayedBatters.indices.contains(index - 1) else { return false }

        let currentPlayer = displayedBatters[index]
        let previousPlayer = displayedBatters[index - 1]
        let isPitcherOrCatcher = currentPlayer.id == viewModel.pitcherID || currentPlayer.id == viewModel.catcherID

        return isPitcherOrCatcher && currentPlayer.speedRating == 2 && previousPlayer.speedRating == 2
    }

    private func warningText(for player: Player) -> String {
        let role: String
        if player.id == viewModel.pitcherID {
            role = "pitcher"
        } else if player.id == viewModel.catcherID {
            role = "catcher"
        } else {
            role = "player"
        }
        return "Warning: No Steal \(role) bats after a No Steal runner"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Team") {
                    TeamPickerView(viewModel: viewModel)
                    Text(viewModel.selectedTeamName)
                        .font(.headline)
                }
                Section("Print / Save") {
                    Button("Share Lineup Grid") {
                        do {
                            lineupPDFURL = try viewModel.createLineupGridPDF()
                            isShowingLineupShareSheet = true
                            lineupExportMessage = "Lineup grid ready."
                        } catch {
                            lineupExportMessage = "Could not create lineup grid: \(error.localizedDescription)"
                        }
                    }

                    if !lineupExportMessage.isEmpty {
                        Text(lineupExportMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Batting Order") {
                    if displayedBatters.isEmpty {
                        Text("Add players first, then they will appear here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(displayedBatters.enumerated()), id: \.element.id) { index, player in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    Text("\(index + 1).")
                                        .fontWeight(.semibold)
                                        .frame(width: 34, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 4) {
                                            Text(viewModel.displayLabel(for: player))
                                            if player.status == .guest {
                                                Text("(Guest)")
                                                    .italic()
                                                    .foregroundStyle(.red)
                                            }
                                        }

                                        if let stats = player.gameChangerStats {
                                            Text(stats.displayText)
                                                .font(.caption2)
                                                .italic()
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()
                                    Text(player.speedRating == 1 ? "Steal" : "No Steal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if hasSlowPitcherCatcherWarning(at: index) {
                                    Text(warningText(for: player))
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .onMove(perform: viewModel.moveBatters)
                    }
                }

                if viewModel.showOnlyNineBattersAndDH {
                    Section("Designated Hitter") {
                        Picker("DH", selection: Binding(
                            get: { viewModel.designatedHitterID },
                            set: { viewModel.designatedHitterID = $0 }
                        )) {
                            Text("No DH selected").tag(UUID?.none)
                            ForEach(viewModel.activePlayers) { player in
                                Text(viewModel.displayLabel(for: player)).tag(Optional(player.id))
                            }
                        }

                        Picker("DH For", selection: Binding(
                            get: { viewModel.designatedHitterForID },
                            set: { viewModel.designatedHitterForID = $0 }
                        )) {
                            Text("Select player").tag(UUID?.none)
                            ForEach(viewModel.activePlayers) { player in
                                Text(viewModel.displayLabel(for: player)).tag(Optional(player.id))
                            }
                        }

                        if let dhID = viewModel.designatedHitterID,
                           let dh = viewModel.player(for: dhID) {
                            HStack {
                                Text("DH")
                                    .fontWeight(.semibold)
                                    .frame(width: 34, alignment: .leading)
                                Text(viewModel.displayLabel(for: dh))
                                Spacer()
                            }
                        }

                        if let dhForID = viewModel.designatedHitterForID,
                           let dhFor = viewModel.player(for: dhForID) {
                            HStack {
                                Text("For")
                                    .fontWeight(.semibold)
                                    .frame(width: 34, alignment: .leading)
                                Text(viewModel.displayLabel(for: dhFor))
                                Spacer()
                            }
                        }
                    }
                }

                Section("How this works") {
                    Text(viewModel.showOnlyNineBattersAndDH ? "Settings are set to show the first 9 batters plus a DH. Use Edit to reorder the batting order." : "All players are shown in the batting order. Use Edit to reorder them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Lineup")
            .toolbar {
                EditButton()
            }
            .onAppear {
                viewModel.syncBattingOrder()
            }
            .sheet(isPresented: $isShowingLineupShareSheet) {
                if let lineupPDFURL {
                    ActivityView(activityItems: [lineupPDFURL])
                } else {
                    Text("No lineup grid available.")
                }
            }
        }
    }
}

struct BaseballFieldLineupView: View {
    let lineup: [FieldPosition: Player]
    let showRatings: Bool
    let showFullNameAndNumber: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.green.opacity(0.22))

                outfieldShape(width: width, height: height)
                    .fill(Color.green.opacity(0.35))

                infieldShape(width: width, height: height)
                    .fill(Color.brown.opacity(0.45))


                baseDiamond(width: width, height: height)
                    .stroke(Color.white.opacity(0.95), lineWidth: 2)

                baseMarker(at: CGPoint(x: width * 0.50, y: height * 0.82), size: 18)
                baseMarker(at: CGPoint(x: width * 0.75, y: height * 0.60), size: 13)
                baseMarker(at: CGPoint(x: width * 0.50, y: height * 0.39), size: 13)
                baseMarker(at: CGPoint(x: width * 0.25, y: height * 0.60), size: 13)

                Circle()
                    .fill(Color.brown.opacity(0.45))
                    .frame(width: 64, height: 64)
                    .position(x: width * 0.50, y: height * 0.61)

                positionMarker(.centerField, at: CGPoint(x: width * 0.50, y: height * 0.14))
                positionMarker(.leftField, at: CGPoint(x: width * 0.20, y: height * 0.28))
                positionMarker(.rightField, at: CGPoint(x: width * 0.80, y: height * 0.28))
                positionMarker(.shortstop, at: CGPoint(x: width * 0.36, y: height * 0.45))
                positionMarker(.secondBase, at: CGPoint(x: width * 0.64, y: height * 0.45))
                positionMarker(.thirdBase, at: CGPoint(x: width * 0.25, y: height * 0.62))
                positionMarker(.firstBase, at: CGPoint(x: width * 0.75, y: height * 0.62))
                positionMarker(.pitcher, at: CGPoint(x: width * 0.50, y: height * 0.62))
                positionMarker(.catcher, at: CGPoint(x: width * 0.50, y: height * 0.90))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private func outfieldShape(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: width * 0.05, y: height * 0.56))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.95, y: height * 0.56),
                control: CGPoint(x: width * 0.50, y: height * -0.04)
            )
            path.addLine(to: CGPoint(x: width * 0.50, y: height * 0.92))
            path.closeSubpath()
        }
    }

    private func infieldShape(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: width * 0.50, y: height * 0.82))
            path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.60))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.50, y: height * 0.39),
                control: CGPoint(x: width * 0.66, y: height * 0.43)
            )
            path.addQuadCurve(
                to: CGPoint(x: width * 0.25, y: height * 0.60),
                control: CGPoint(x: width * 0.34, y: height * 0.43)
            )
            path.closeSubpath()
        }
    }


    private func baseDiamond(width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: width * 0.50, y: height * 0.82))
            path.addLine(to: CGPoint(x: width * 0.75, y: height * 0.60))
            path.addLine(to: CGPoint(x: width * 0.50, y: height * 0.39))
            path.addLine(to: CGPoint(x: width * 0.25, y: height * 0.60))
            path.closeSubpath()
        }
    }

    private func baseMarker(at point: CGPoint, size: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(45))
            .position(point)
    }

    private func positionMarker(_ position: FieldPosition, at point: CGPoint) -> some View {
        let player = lineup[position]
        let rating = player?.positionRatings[position]
        let positionText = label(for: position)

        return VStack(spacing: 3) {
            Text(positionText)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.9))
                .clipShape(Capsule())

            Text(playerLabel(player))
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(Color(uiColor: .label))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .frame(width: 96)
                .background(Color(uiColor: .systemBackground).opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            if showRatings, let rating {
                Text("Rating \(rating)")
                    .font(.caption2)
                    .foregroundStyle(Color(uiColor: .label))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(uiColor: .systemBackground).opacity(0.80))
                    .clipShape(Capsule())
            }
        }
        .position(point)
    }

    private func playerLabel(_ player: Player?) -> String {
        guard let player else { return "—" }

        let nameParts = player.name.split(separator: " ").map(String.init)
        let lastName = nameParts.last ?? player.name
        let firstInitial = nameParts.first?.first.map { "\($0)." } ?? ""
        let initialLastName = firstInitial.isEmpty ? lastName : "\(firstInitial) \(lastName)"

        let baseLabel: String
        if showFullNameAndNumber {
            baseLabel = player.number.isEmpty ? player.name : "#\(player.number) \(player.name)"
        } else {
            baseLabel = player.number.isEmpty ? initialLastName : "#\(player.number) \(initialLastName)"
        }

        return player.status == .guest ? "\(baseLabel) (Guest)" : baseLabel
    }

    private func label(for position: FieldPosition) -> String {
        position.rawValue
    }
}

// MARK: - Settings Tab

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

struct ImportDocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: LineupViewModel
    @State private var isShowingPlayerImportPicker = false
    @State private var isImportingPlayerOnly = false
    @State private var isShowingGameChangerImportPicker = false
    @State private var backupStatusMessage = ""
    @State private var gameChangerStatusMessage = ""
    @State private var isShowingShareSheet = false
    @State private var shareURL: URL?
    @State private var playerShareURL: URL?
    @State private var isShowingDeletePlayerDialog = false
    @State private var isShowingDeletePlayerDataConfirmation = false
    @State private var editedTeamName = ""
    @FocusState private var isTeamNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Team") {
                    TeamPickerView(viewModel: viewModel)
                    TextField("Team name", text: $editedTeamName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTeamNameFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.updateSelectedTeamName(editedTeamName)
                            isTeamNameFocused = false
                        }
                    Button("Save Team Name") {
                        viewModel.updateSelectedTeamName(editedTeamName)
                        isTeamNameFocused = false
                    }
                }
                Section("Lineup Display") {
                    Toggle("Show ratings on field", isOn: $viewModel.showRatingsOnField)
                    Toggle("Show assigned lineup table", isOn: $viewModel.showAssignedLineupTable)
                    Toggle("Use first initial, last name, and number", isOn: Binding(
                        get: { !viewModel.showFullNameAndNumber },
                        set: { viewModel.showFullNameAndNumber = !$0 }
                    ))
                    Toggle("Show bench on field tab", isOn: $viewModel.showBenchOnField)
                }

                Section("Batting Order") {
                    Toggle("Only show 9 batters and a DH", isOn: $viewModel.showOnlyNineBattersAndDH)
                    Toggle("Warn when No Steal P/C bats after No Steal runner", isOn: $viewModel.showSlowSpeedBattingWarnings)
                }

                Section("Fall Ball") {
                    Toggle("Fall Ball", isOn: $viewModel.fallBallEnabled)

                    if viewModel.fallBallEnabled {
                        Toggle("Youth", isOn: $viewModel.fallBallYouthEnabled)

                        Text("Fall Ball generates all 9 fielding innings randomly while trying to keep bench time balanced. Youth mode removes manual pitcher/catcher selection and randomly assigns every active player across every position.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }



                Section("Player") {
                    Button("Import Player") {
                        isImportingPlayerOnly = true
                        isShowingPlayerImportPicker = true
                    }

                    Button("Share Player") {
                        do {
                            let data = viewModel.exportPlayerNameNumberData()
                            let url = FileManager.default.temporaryDirectory.appendingPathComponent("LineupChanger-Players.json")
                            try data.write(to: url, options: .atomic)
                            playerShareURL = url
                            shareURL = url
                            isShowingShareSheet = true
                            backupStatusMessage = "Player file ready to share."
                        } catch {
                            backupStatusMessage = "Share player failed: \(error.localizedDescription)"
                        }
                    }

                    Button("Delete Player", role: .destructive) {
                        isShowingDeletePlayerDialog = true
                    }

                    Text("Import or share players only. This file includes only player names and numbers in JSON format.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Player Data") {
                    Button("Import Player Data") {
                        isImportingPlayerOnly = false
                        isShowingPlayerImportPicker = true
                    }

                    Button("Share Player Data") {
                        do {
                            let data = viewModel.exportAppStateData()
                            let url = FileManager.default.temporaryDirectory.appendingPathComponent("LineupChanger-Player-Data.json")
                            try data.write(to: url, options: .atomic)
                            shareURL = url
                            isShowingShareSheet = true
                            backupStatusMessage = "Player data file ready to share."
                        } catch {
                            backupStatusMessage = "Share player data failed: \(error.localizedDescription)"
                        }
                    }

                    Button("Delete Player Data", role: .destructive) {
                        isShowingDeletePlayerDataConfirmation = true
                    }

                    Text("Import or share the full backup. This includes players, numbers, steal ability, position ratings, field lineups by inning, batting order, DH settings, and app settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Section("GameChanger") {
                        Button("Import GameChanger Stats") {
                            isShowingGameChangerImportPicker = true
                        }

                        Button("Clear GameChanger Stats", role: .destructive) {
                            viewModel.clearGameChangerStats()
                            gameChangerStatusMessage = "GameChanger stats cleared."
                        }

                        Text("Import a GameChanger CSV export. Players are matched by first and last name. Imported stats shown on the Lineup tab: AVG, OBP, OPS, SLG, H, RBI, R, BB, and SO.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if !gameChangerStatusMessage.isEmpty {
                            Text(gameChangerStatusMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !backupStatusMessage.isEmpty {
                        Text(backupStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add players, give each player one or more positions, rate each position from 1 to 5, manually set pitcher and catcher, then auto-fill the rest of the field.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Divider()

                        Text("Legal")
                            .font(.headline)

                        Text("© 2026 Richard C. Morris Jr. All rights reserved.")
                            .font(.footnote)

                        Text("This application and its contents are proprietary. Unauthorized copying, distribution, modification, or reverse engineering is strictly prohibited.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text("This app is provided \"as is\" without warranty of any kind, express or implied, including but not limited to fitness for a particular purpose.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                editedTeamName = viewModel.selectedTeamName
            }
            .onChange(of: viewModel.selectedTeamIndex) { _, _ in
                editedTeamName = viewModel.selectedTeamName
                isTeamNameFocused = false
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        viewModel.updateSelectedTeamName(editedTeamName)
                        isTeamNameFocused = false
                    }
                }
            }
            .sheet(isPresented: $isShowingPlayerImportPicker) {
                ImportDocumentPicker(
                    contentTypes: [.json, .data],
                    onPick: { url in
                        do {
                            let data = try Data(contentsOf: url)
                            if isImportingPlayerOnly {
                                try viewModel.importPlayerNameNumberData(data)
                                backupStatusMessage = "Player import complete."
                            } else {
                                try viewModel.importAppStateData(data)
                                backupStatusMessage = "Player data import complete."
                            }
                        } catch {
                            backupStatusMessage = "Import failed: \(error.localizedDescription)"
                        }
                        isShowingPlayerImportPicker = false
                    },
                    onCancel: {
                        backupStatusMessage = "Import cancelled."
                        isShowingPlayerImportPicker = false
                    }
                )
            }
            .sheet(isPresented: $isShowingGameChangerImportPicker) {
                ImportDocumentPicker(
                    contentTypes: [.commaSeparatedText, .plainText, .data],
                    onPick: { url in
                        do {
                            let data = try Data(contentsOf: url)
                            let matchedCount = try viewModel.importGameChangerStatsData(data)
                            gameChangerStatusMessage = "Imported GameChanger stats for \(matchedCount) player(s)."
                        } catch {
                            gameChangerStatusMessage = "Import failed: \(error.localizedDescription)"
                        }
                        isShowingGameChangerImportPicker = false
                    },
                    onCancel: {
                        gameChangerStatusMessage = "Import cancelled."
                        isShowingGameChangerImportPicker = false
                    }
                )
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let shareURL {
                    ActivityView(activityItems: [shareURL])
                } else {
                    Text("No backup file available to share.")
                }
            }
            .confirmationDialog("Delete Player", isPresented: $isShowingDeletePlayerDialog, titleVisibility: .visible) {
                ForEach(viewModel.players) { player in
                    Button(viewModel.displayLabel(for: player), role: .destructive) {
                        viewModel.deletePlayer(playerID: player.id)
                        backupStatusMessage = "Deleted \(player.name)."
                    }
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Choose a player to delete.")
            }
            .confirmationDialog("Delete All Player Data?", isPresented: $isShowingDeletePlayerDataConfirmation, titleVisibility: .visible) {
                Button("Delete All Player Data", role: .destructive) {
                    viewModel.deleteAllPlayerData()
                    backupStatusMessage = "All player data deleted."
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all players, batting order, field lineups, pitcher/catcher selections, DH settings, and inning data for the current team.")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
}


