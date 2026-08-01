// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Gesture arena team system — manages groups of gesture recognizers competing
/// as a unit in the gesture arena.
///
/// **Dart Source:** `packages/flutter/lib/src/gestures/team.dart`
/// **Lines:** 1-163

import FlutterSwiftBridge

// MARK: - CombiningGestureArenaEntry

/// Wraps a ``CombiningGestureArenaMember`` and a ``GestureArenaMember``,
/// delegating ``resolve(_:)`` to the combiner.
///
/// **Dart Source:** `team.dart:17-27`
/// **Original Name:** `_CombiningGestureArenaEntry`
///
/// DIFFERENCE FROM DART: Dart uses a private class that `implements
/// GestureArenaEntry`. In Swift, ``GestureArenaEntry`` is a concrete class
/// (not a protocol), so this subclasses it and overrides ``resolve(_:)``.
internal class CombiningGestureArenaEntry: GestureArenaEntry {
    /// **Dart Source:** `team.dart:18`
    init(_ combiner: CombiningGestureArenaMember, _ member: GestureArenaMember) {
        self._combiner = combiner
        self._member = member
        super.init()
    }

    /// **Dart Source:** `team.dart:20`
    private let _combiner: CombiningGestureArenaMember

    /// **Dart Source:** `team.dart:21`
    private let _member: GestureArenaMember

    /// **Dart Source:** `team.dart:23-26`
    override public func resolve(_ disposition: GestureDisposition) {
        _combiner._resolve(_member, disposition)
    }
}

// MARK: - CombiningGestureArenaMember

/// Combines multiple ``GestureArenaMember`` objects into a single arena entry
/// for a given pointer, so they compete as a team rather than individually.
///
/// When the team wins (accepted), the captain (if set) or the winning member
/// receives ``acceptGesture(_:)``, and all other members are rejected. When the
/// team loses (rejected), all members are rejected.
///
/// **Dart Source:** `team.dart:29-94`
/// **Original Name:** `_CombiningGestureArenaMember`
///
/// DIFFERENCE FROM DART: Renamed from `_CombiningGestureArenaMember` to
/// `CombiningGestureArenaMember` with `internal` access. REASON: Swift does not
/// support file-private classes that need to be referenced by other types within
/// the same module.
internal class CombiningGestureArenaMember: GestureArenaMember {
    /// **Dart Source:** `team.dart:30`
    init(_ owner: GestureArenaTeam, _ pointer: Int) {
        self._owner = owner
        self._pointer = pointer
    }

    /// **Dart Source:** `team.dart:32`
    private let _owner: GestureArenaTeam

    /// **Dart Source:** `team.dart:33`
    private var _members: [GestureArenaMember] = []

    /// **Dart Source:** `team.dart:34`
    private let _pointer: Int

    /// **Dart Source:** `team.dart:36`
    private var _resolved: Bool = false

    /// **Dart Source:** `team.dart:37`
    private var _winner: GestureArenaMember?

    /// **Dart Source:** `team.dart:38`
    private var _entry: GestureArenaEntry?

    // MARK: - GestureArenaMember

    /// Called when this combined member wins the arena for the given pointer id.
    ///
    /// The captain (if set on the owner team) wins; otherwise the first member
    /// added wins. All other members are rejected.
    ///
    /// **Dart Source:** `team.dart:40-52`
    func acceptGesture(_ pointer: Int) {
        assert(_pointer == pointer)
        assert(_winner != nil || !_members.isEmpty)
        _close()
        if _winner == nil {
            _winner = _owner.captain ?? _members[0]
        }
        for member in _members {
            if member !== _winner {
                member.rejectGesture(pointer)
            }
        }
        _winner!.acceptGesture(pointer)
    }

    /// Called when this combined member loses the arena for the given pointer id.
    ///
    /// All members are rejected.
    ///
    /// **Dart Source:** `team.dart:54-61`
    func rejectGesture(_ pointer: Int) {
        assert(_pointer == pointer)
        _close()
        for member in _members {
            member.rejectGesture(pointer)
        }
    }

    // MARK: - Internal Methods

    /// Removes this combiner from the owner's combiner map.
    ///
    /// **Dart Source:** `team.dart:63-68`
    private func _close() {
        assert(!_resolved)
        _resolved = true
        let combiner = _owner._combiners.removeValue(forKey: _pointer)
        assert(combiner === self)
    }

    /// Adds a member to this combiner for the given pointer.
    ///
    /// Lazily registers this combiner in the global gesture arena on the first
    /// call. Returns a ``CombiningGestureArenaEntry`` that delegates resolution
    /// back to this combiner.
    ///
    /// **Dart Source:** `team.dart:70-76`
    func _add(_ pointer: Int, _ member: GestureArenaMember) -> GestureArenaEntry {
        assert(!_resolved)
        assert(_pointer == pointer)
        _members.append(member)
        if _entry == nil {
            _entry = GestureBinding.instance.gestureArena.add(pointer, self)
        }
        return CombiningGestureArenaEntry(self, member)
    }

    /// Resolves an individual member within this combiner.
    ///
    /// If the member accepts, the captain (or that member) becomes the winner
    /// and the entire team entry is resolved as accepted. If the member rejects,
    /// it is removed; if no members remain, the entire team entry is resolved as
    /// rejected.
    ///
    /// **Dart Source:** `team.dart:78-93`
    func _resolve(_ member: GestureArenaMember, _ disposition: GestureDisposition) {
        if _resolved {
            return
        }
        switch disposition {
        case .accepted:
            if _winner == nil {
                _winner = _owner.captain ?? member
            }
            _entry!.resolve(disposition)
        case .rejected:
            _members.removeAll { $0 === member }
            member.rejectGesture(_pointer)
            if _members.isEmpty {
                _entry!.resolve(disposition)
            }
        }
    }
}

// MARK: - GestureArenaTeam

/// A group of ``GestureArenaMember`` objects that are competing as a unit in the
/// ``GestureArenaManager``.
///
/// Normally, a recognizer competes directly in the ``GestureArenaManager`` to
/// recognize a sequence of pointer events as a gesture. With a
/// ``GestureArenaTeam``, recognizers can compete in the arena in a group with
/// other recognizers. Arena teams may have a captain which wins the arena on
/// behalf of its team.
///
/// When gesture recognizers are in a team together without a captain, then once
/// there are no other competing gestures in the arena, the first gesture to
/// have been added to the team automatically wins, instead of the gestures
/// continuing to compete against each other.
///
/// When gesture recognizers are in a team with a captain, then once one of the
/// team members claims victory or there are no other competing gestures in the
/// arena, the captain wins the arena, and all other team members lose.
///
/// For example, `Slider` uses a team without a captain to support both a
/// `HorizontalDragGestureRecognizer` and a `TapGestureRecognizer`, but without
/// the drag recognizer having to wait until the user has dragged outside the
/// slop region of the tap gesture before triggering. Since they compete as a
/// team, as soon as any other recognizers are out of the arena, the drag
/// recognizer wins, even if the user has not actually dragged yet. On the other
/// hand, if the tap can win outright, before the other recognizers are taken
/// out of the arena (e.g. if the slider is in a vertical scrolling list and the
/// user places their finger on the touch surface then lifts it, so that neither
/// the horizontal nor vertical drag recognizers can claim victory) the tap
/// recognizer still actually wins, despite being in the team.
///
/// `AndroidView` uses a team with a captain to decide which gestures are
/// forwarded to the native view. For example if we want to forward taps and
/// vertical scrolls to a native Android view, `TapGestureRecognizer`s and
/// `VerticalDragGestureRecognizer` are added to a team with a captain (the
/// captain is set to be a gesture recognizer that never explicitly claims the
/// gesture).
///
/// The captain allows `AndroidView` to know when any gestures in the team has
/// been recognized (or all other arena members are out), once the captain wins
/// the gesture is forwarded to the Android view.
///
/// To assign a gesture recognizer to a team, set
/// `OneSequenceGestureRecognizer.team` to an instance of ``GestureArenaTeam``.
///
/// **Dart Source:** `team.dart:96-163`
public class GestureArenaTeam {
    public init() {}

    /// **Dart Source:** `team.dart:140`
    internal var _combiners: [Int: CombiningGestureArenaMember] = [:]

    /// A member that wins on behalf of the entire team.
    ///
    /// If not nil, when any one of the ``GestureArenaTeam`` members claims
    /// victory the captain accepts the gesture.
    /// If nil, the member that claims a victory accepts the gesture.
    ///
    /// **Dart Source:** `team.dart:142-147`
    public var captain: GestureArenaMember?

    /// Adds a new member to the arena on behalf of this team.
    ///
    /// Used by `GestureRecognizer` subclasses that wish to compete in the arena
    /// using this team.
    ///
    /// To assign a gesture recognizer to a team, see
    /// `OneSequenceGestureRecognizer.team`.
    ///
    /// **Dart Source:** `team.dart:149-162`
    public func add(_ pointer: Int, _ member: GestureArenaMember) -> GestureArenaEntry {
        let combiner: CombiningGestureArenaMember
        if let existing = _combiners[pointer] {
            combiner = existing
        } else {
            let newCombiner = CombiningGestureArenaMember(self, pointer)
            _combiners[pointer] = newCombiner
            combiner = newCombiner
        }
        return combiner._add(pointer, member)
    }
}
