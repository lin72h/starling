// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// ChildSemanticsConfigurationsResult and its builder, migrated from `semantics.dart`.
///
/// **Dart Source:** `packages/flutter/lib/src/semantics/semantics.dart`
/// **Lines:** 529-614

// MARK: - ChildSemanticsConfigurationsResult

/// The result that contains the arrangement for the child
/// [SemanticsConfiguration]s.
///
/// When the [PipelineOwner] builds the semantics tree, it uses the returned
/// [ChildSemanticsConfigurationsResult] from
/// [SemanticsConfiguration.childConfigurationsDelegate] to decide how semantics
/// nodes should form.
///
/// Use [ChildSemanticsConfigurationsResultBuilder] to build the result.
///
/// **Dart Source:** `semantics.dart:529-564`
/// **Original Name:** `ChildSemanticsConfigurationsResult`
///
// DIFFERENCE FROM DART: The private constructor `_()` is replaced by an
// internal initializer. Swift does not have Dart's library-private named
// constructors, so we use `internal` access to restrict creation to this module.
// REASON: Only the builder should be able to create instances.
public final class ChildSemanticsConfigurationsResult {

  /// Internal initializer -- only `ChildSemanticsConfigurationsResultBuilder.build()` should call this.
  ///
  /// **Dart Source:** `semantics.dart:539`
  /// **Original:** `ChildSemanticsConfigurationsResult._(this.mergeUp, this.siblingMergeGroups);`
  internal init(
    mergeUp: [SemanticsConfiguration],
    siblingMergeGroups: [[SemanticsConfiguration]]
  ) {
    self.mergeUp = mergeUp
    self.siblingMergeGroups = siblingMergeGroups
  }

  /// Returns the [SemanticsConfiguration]s that are supposed to be merged into
  /// the parent semantics node.
  ///
  /// [SemanticsConfiguration]s that are either semantics boundaries or are
  /// conflicting with other [SemanticsConfiguration]s will form explicit
  /// semantics nodes. All others will be merged into the parent.
  ///
  /// **Dart Source:** `semantics.dart:541-547`
  /// **Original:** `final List<SemanticsConfiguration> mergeUp;`
  public let mergeUp: [SemanticsConfiguration]

  /// The groups of child semantics configurations that want to merge together
  /// and form a sibling [SemanticsNode].
  ///
  /// All the [SemanticsConfiguration]s in a given group that are either
  /// semantics boundaries or are conflicting with other
  /// [SemanticsConfiguration]s of the same group will be excluded from the
  /// sibling merge group and form independent semantics nodes as usual.
  ///
  /// The result [SemanticsNode]s from the merges are attached as the sibling
  /// nodes of the immediate parent semantics node. For example, a `RenderObjectA`
  /// has a rendering child, `RenderObjectB`. If both of them form their own
  /// semantics nodes, `SemanticsNodeA` and `SemanticsNodeB`, any semantics node
  /// created from sibling merge groups of `RenderObjectB` will be attached to
  /// `SemanticsNodeA` as a sibling of `SemanticsNodeB`.
  ///
  /// **Dart Source:** `semantics.dart:549-563`
  /// **Original:** `final List<List<SemanticsConfiguration>> siblingMergeGroups;`
  public let siblingMergeGroups: [[SemanticsConfiguration]]
}

// MARK: - ChildSemanticsConfigurationsResultBuilder

/// The builder to build a [ChildSemanticsConfigurationsResult] based on its
/// annotations.
///
/// To use this builder, one can use [markAsMergeUp] and
/// [markAsSiblingMergeGroup] to annotate the arrangement of
/// [SemanticsConfiguration]s. Once all the configs are annotated, use [build]
/// to generate the [ChildSemanticsConfigurationsResult].
///
/// **Dart Source:** `semantics.dart:566-614`
/// **Original Name:** `ChildSemanticsConfigurationsResultBuilder`
public final class ChildSemanticsConfigurationsResultBuilder {

  /// Creates a [ChildSemanticsConfigurationsResultBuilder].
  ///
  /// **Dart Source:** `semantics.dart:574-575`
  /// **Original:** `ChildSemanticsConfigurationsResultBuilder();`
  public init() {}

  /// **Dart Source:** `semantics.dart:577`
  /// **Original:** `final List<SemanticsConfiguration> _mergeUp = <SemanticsConfiguration>[];`
  private var _mergeUp: [SemanticsConfiguration] = []

  /// **Dart Source:** `semantics.dart:578`
  /// **Original:** `final List<List<SemanticsConfiguration>> _siblingMergeGroups = ...;`
  private var _siblingMergeGroups: [[SemanticsConfiguration]] = []

  /// Marks the [SemanticsConfiguration] to be merged into the parent semantics
  /// node.
  ///
  /// The [SemanticsConfiguration] will be added to the
  /// [ChildSemanticsConfigurationsResult.mergeUp] that this builder builds.
  ///
  /// **Dart Source:** `semantics.dart:580-585`
  /// **Original:** `void markAsMergeUp(SemanticsConfiguration config) => _mergeUp.add(config);`
  public func markAsMergeUp(_ config: SemanticsConfiguration) {
    _mergeUp.append(config)
  }

  /// Marks a group of [SemanticsConfiguration]s to merge together
  /// and form a sibling [SemanticsNode].
  ///
  /// The group of [SemanticsConfiguration]s will be added to the
  /// [ChildSemanticsConfigurationsResult.siblingMergeGroups] that this builder
  /// builds.
  ///
  /// **Dart Source:** `semantics.dart:587-593`
  /// **Original:** `void markAsSiblingMergeGroup(List<SemanticsConfiguration> configs) => ...;`
  public func markAsSiblingMergeGroup(_ configs: [SemanticsConfiguration]) {
    _siblingMergeGroups.append(configs)
  }

  /// Builds a [ChildSemanticsConfigurationsResult] containing the arrangement.
  ///
  /// In debug mode, asserts that no [SemanticsConfiguration] appears more than
  /// once across `mergeUp` and all `siblingMergeGroups`.
  ///
  /// **Dart Source:** `semantics.dart:595-613`
  /// **Original:**
  /// ```dart
  /// ChildSemanticsConfigurationsResult build() {
  ///   assert(() {
  ///     final Set<SemanticsConfiguration> seenConfigs = ...;
  ///     for (final config in [..._mergeUp, ..._siblingMergeGroups.flattened]) {
  ///       assert(seenConfigs.add(config), 'Duplicated SemanticsConfigurations...');
  ///     }
  ///     return true;
  ///   }());
  ///   return ChildSemanticsConfigurationsResult._(_mergeUp, _siblingMergeGroups);
  /// }
  /// ```
  public func build() -> ChildSemanticsConfigurationsResult {
    // Debug-only duplicate check, matching Dart's assert closure pattern.
    assert({
      var seenConfigs: Set<SemanticsConfiguration> = []
      let allConfigs: [SemanticsConfiguration] =
        _mergeUp + _siblingMergeGroups.flatMap { $0 }
      for config in allConfigs {
        let inserted = seenConfigs.insert(config).inserted
        assert(
          inserted,
          "Duplicated SemanticsConfigurations. This can happen if the same "
            + "SemanticsConfiguration was marked twice in markAsMergeUp and/or "
            + "markAsSiblingMergeGroup"
        )
      }
      return true
    }())
    return ChildSemanticsConfigurationsResult(
      mergeUp: _mergeUp,
      siblingMergeGroups: _siblingMergeGroups
    )
  }
}

// MARK: - ChildSemanticsConfigurationsDelegate

/// Signature for the [SemanticsConfiguration.childConfigurationsDelegate].
///
/// The input list contains all [SemanticsConfiguration]s that rendering
/// children want to merge upward. One can tag a render child with a
/// [SemanticsTag] and look up its [SemanticsConfiguration]s through
/// [SemanticsConfiguration.tagsChildrenWith].
///
/// The return value is the arrangement of these configs, including which
/// configs continue to merge upward and which configs form sibling merge group.
///
/// Use [ChildSemanticsConfigurationsResultBuilder] to generate the return
/// value.
///
/// **Dart Source:** `semantics.dart:102-115`
/// **Original:**
/// ```dart
/// typedef ChildSemanticsConfigurationsDelegate =
///     ChildSemanticsConfigurationsResult Function(List<SemanticsConfiguration>);
/// ```
public typealias ChildSemanticsConfigurationsDelegate =
  ([SemanticsConfiguration]) -> ChildSemanticsConfigurationsResult
