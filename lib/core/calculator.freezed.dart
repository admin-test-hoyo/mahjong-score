// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'calculator.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MahjongRule {

 int get rate; int get chipRate; int get returnScore; List<int> get uma; int get oka; int get tobiPrize; int get yakumanRonPrize; int get yakumanTsumoPrize; int get yakumanPaoPrize; int get totalFee;
/// Create a copy of MahjongRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MahjongRuleCopyWith<MahjongRule> get copyWith => _$MahjongRuleCopyWithImpl<MahjongRule>(this as MahjongRule, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MahjongRule&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.chipRate, chipRate) || other.chipRate == chipRate)&&(identical(other.returnScore, returnScore) || other.returnScore == returnScore)&&const DeepCollectionEquality().equals(other.uma, uma)&&(identical(other.oka, oka) || other.oka == oka)&&(identical(other.tobiPrize, tobiPrize) || other.tobiPrize == tobiPrize)&&(identical(other.yakumanRonPrize, yakumanRonPrize) || other.yakumanRonPrize == yakumanRonPrize)&&(identical(other.yakumanTsumoPrize, yakumanTsumoPrize) || other.yakumanTsumoPrize == yakumanTsumoPrize)&&(identical(other.yakumanPaoPrize, yakumanPaoPrize) || other.yakumanPaoPrize == yakumanPaoPrize)&&(identical(other.totalFee, totalFee) || other.totalFee == totalFee));
}


@override
int get hashCode => Object.hash(runtimeType,rate,chipRate,returnScore,const DeepCollectionEquality().hash(uma),oka,tobiPrize,yakumanRonPrize,yakumanTsumoPrize,yakumanPaoPrize,totalFee);

@override
String toString() {
  return 'MahjongRule(rate: $rate, chipRate: $chipRate, returnScore: $returnScore, uma: $uma, oka: $oka, tobiPrize: $tobiPrize, yakumanRonPrize: $yakumanRonPrize, yakumanTsumoPrize: $yakumanTsumoPrize, yakumanPaoPrize: $yakumanPaoPrize, totalFee: $totalFee)';
}


}

/// @nodoc
abstract mixin class $MahjongRuleCopyWith<$Res>  {
  factory $MahjongRuleCopyWith(MahjongRule value, $Res Function(MahjongRule) _then) = _$MahjongRuleCopyWithImpl;
@useResult
$Res call({
 int rate, int chipRate, int returnScore, List<int> uma, int oka, int tobiPrize, int yakumanRonPrize, int yakumanTsumoPrize, int yakumanPaoPrize, int totalFee
});




}
/// @nodoc
class _$MahjongRuleCopyWithImpl<$Res>
    implements $MahjongRuleCopyWith<$Res> {
  _$MahjongRuleCopyWithImpl(this._self, this._then);

  final MahjongRule _self;
  final $Res Function(MahjongRule) _then;

/// Create a copy of MahjongRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? rate = null,Object? chipRate = null,Object? returnScore = null,Object? uma = null,Object? oka = null,Object? tobiPrize = null,Object? yakumanRonPrize = null,Object? yakumanTsumoPrize = null,Object? yakumanPaoPrize = null,Object? totalFee = null,}) {
  return _then(_self.copyWith(
rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as int,chipRate: null == chipRate ? _self.chipRate : chipRate // ignore: cast_nullable_to_non_nullable
as int,returnScore: null == returnScore ? _self.returnScore : returnScore // ignore: cast_nullable_to_non_nullable
as int,uma: null == uma ? _self.uma : uma // ignore: cast_nullable_to_non_nullable
as List<int>,oka: null == oka ? _self.oka : oka // ignore: cast_nullable_to_non_nullable
as int,tobiPrize: null == tobiPrize ? _self.tobiPrize : tobiPrize // ignore: cast_nullable_to_non_nullable
as int,yakumanRonPrize: null == yakumanRonPrize ? _self.yakumanRonPrize : yakumanRonPrize // ignore: cast_nullable_to_non_nullable
as int,yakumanTsumoPrize: null == yakumanTsumoPrize ? _self.yakumanTsumoPrize : yakumanTsumoPrize // ignore: cast_nullable_to_non_nullable
as int,yakumanPaoPrize: null == yakumanPaoPrize ? _self.yakumanPaoPrize : yakumanPaoPrize // ignore: cast_nullable_to_non_nullable
as int,totalFee: null == totalFee ? _self.totalFee : totalFee // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [MahjongRule].
extension MahjongRulePatterns on MahjongRule {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MahjongRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MahjongRule() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MahjongRule value)  $default,){
final _that = this;
switch (_that) {
case _MahjongRule():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MahjongRule value)?  $default,){
final _that = this;
switch (_that) {
case _MahjongRule() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int rate,  int chipRate,  int returnScore,  List<int> uma,  int oka,  int tobiPrize,  int yakumanRonPrize,  int yakumanTsumoPrize,  int yakumanPaoPrize,  int totalFee)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MahjongRule() when $default != null:
return $default(_that.rate,_that.chipRate,_that.returnScore,_that.uma,_that.oka,_that.tobiPrize,_that.yakumanRonPrize,_that.yakumanTsumoPrize,_that.yakumanPaoPrize,_that.totalFee);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int rate,  int chipRate,  int returnScore,  List<int> uma,  int oka,  int tobiPrize,  int yakumanRonPrize,  int yakumanTsumoPrize,  int yakumanPaoPrize,  int totalFee)  $default,) {final _that = this;
switch (_that) {
case _MahjongRule():
return $default(_that.rate,_that.chipRate,_that.returnScore,_that.uma,_that.oka,_that.tobiPrize,_that.yakumanRonPrize,_that.yakumanTsumoPrize,_that.yakumanPaoPrize,_that.totalFee);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int rate,  int chipRate,  int returnScore,  List<int> uma,  int oka,  int tobiPrize,  int yakumanRonPrize,  int yakumanTsumoPrize,  int yakumanPaoPrize,  int totalFee)?  $default,) {final _that = this;
switch (_that) {
case _MahjongRule() when $default != null:
return $default(_that.rate,_that.chipRate,_that.returnScore,_that.uma,_that.oka,_that.tobiPrize,_that.yakumanRonPrize,_that.yakumanTsumoPrize,_that.yakumanPaoPrize,_that.totalFee);case _:
  return null;

}
}

}

/// @nodoc


class _MahjongRule implements MahjongRule {
  const _MahjongRule({this.rate = 50, this.chipRate = 100, this.returnScore = 30000, final  List<int> uma = const [20, 10, -10, -20], this.oka = 20, this.tobiPrize = 10, this.yakumanRonPrize = 10, this.yakumanTsumoPrize = 15, this.yakumanPaoPrize = 15, this.totalFee = 0}): _uma = uma;
  

@override@JsonKey() final  int rate;
@override@JsonKey() final  int chipRate;
@override@JsonKey() final  int returnScore;
 final  List<int> _uma;
@override@JsonKey() List<int> get uma {
  if (_uma is EqualUnmodifiableListView) return _uma;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_uma);
}

@override@JsonKey() final  int oka;
@override@JsonKey() final  int tobiPrize;
@override@JsonKey() final  int yakumanRonPrize;
@override@JsonKey() final  int yakumanTsumoPrize;
@override@JsonKey() final  int yakumanPaoPrize;
@override@JsonKey() final  int totalFee;

/// Create a copy of MahjongRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MahjongRuleCopyWith<_MahjongRule> get copyWith => __$MahjongRuleCopyWithImpl<_MahjongRule>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MahjongRule&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.chipRate, chipRate) || other.chipRate == chipRate)&&(identical(other.returnScore, returnScore) || other.returnScore == returnScore)&&const DeepCollectionEquality().equals(other._uma, _uma)&&(identical(other.oka, oka) || other.oka == oka)&&(identical(other.tobiPrize, tobiPrize) || other.tobiPrize == tobiPrize)&&(identical(other.yakumanRonPrize, yakumanRonPrize) || other.yakumanRonPrize == yakumanRonPrize)&&(identical(other.yakumanTsumoPrize, yakumanTsumoPrize) || other.yakumanTsumoPrize == yakumanTsumoPrize)&&(identical(other.yakumanPaoPrize, yakumanPaoPrize) || other.yakumanPaoPrize == yakumanPaoPrize)&&(identical(other.totalFee, totalFee) || other.totalFee == totalFee));
}


@override
int get hashCode => Object.hash(runtimeType,rate,chipRate,returnScore,const DeepCollectionEquality().hash(_uma),oka,tobiPrize,yakumanRonPrize,yakumanTsumoPrize,yakumanPaoPrize,totalFee);

@override
String toString() {
  return 'MahjongRule(rate: $rate, chipRate: $chipRate, returnScore: $returnScore, uma: $uma, oka: $oka, tobiPrize: $tobiPrize, yakumanRonPrize: $yakumanRonPrize, yakumanTsumoPrize: $yakumanTsumoPrize, yakumanPaoPrize: $yakumanPaoPrize, totalFee: $totalFee)';
}


}

/// @nodoc
abstract mixin class _$MahjongRuleCopyWith<$Res> implements $MahjongRuleCopyWith<$Res> {
  factory _$MahjongRuleCopyWith(_MahjongRule value, $Res Function(_MahjongRule) _then) = __$MahjongRuleCopyWithImpl;
@override @useResult
$Res call({
 int rate, int chipRate, int returnScore, List<int> uma, int oka, int tobiPrize, int yakumanRonPrize, int yakumanTsumoPrize, int yakumanPaoPrize, int totalFee
});




}
/// @nodoc
class __$MahjongRuleCopyWithImpl<$Res>
    implements _$MahjongRuleCopyWith<$Res> {
  __$MahjongRuleCopyWithImpl(this._self, this._then);

  final _MahjongRule _self;
  final $Res Function(_MahjongRule) _then;

/// Create a copy of MahjongRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? rate = null,Object? chipRate = null,Object? returnScore = null,Object? uma = null,Object? oka = null,Object? tobiPrize = null,Object? yakumanRonPrize = null,Object? yakumanTsumoPrize = null,Object? yakumanPaoPrize = null,Object? totalFee = null,}) {
  return _then(_MahjongRule(
rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as int,chipRate: null == chipRate ? _self.chipRate : chipRate // ignore: cast_nullable_to_non_nullable
as int,returnScore: null == returnScore ? _self.returnScore : returnScore // ignore: cast_nullable_to_non_nullable
as int,uma: null == uma ? _self._uma : uma // ignore: cast_nullable_to_non_nullable
as List<int>,oka: null == oka ? _self.oka : oka // ignore: cast_nullable_to_non_nullable
as int,tobiPrize: null == tobiPrize ? _self.tobiPrize : tobiPrize // ignore: cast_nullable_to_non_nullable
as int,yakumanRonPrize: null == yakumanRonPrize ? _self.yakumanRonPrize : yakumanRonPrize // ignore: cast_nullable_to_non_nullable
as int,yakumanTsumoPrize: null == yakumanTsumoPrize ? _self.yakumanTsumoPrize : yakumanTsumoPrize // ignore: cast_nullable_to_non_nullable
as int,yakumanPaoPrize: null == yakumanPaoPrize ? _self.yakumanPaoPrize : yakumanPaoPrize // ignore: cast_nullable_to_non_nullable
as int,totalFee: null == totalFee ? _self.totalFee : totalFee // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$PlayerInput {

 int get id; int get score; int get chip; int get specialPrizePt;
/// Create a copy of PlayerInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerInputCopyWith<PlayerInput> get copyWith => _$PlayerInputCopyWithImpl<PlayerInput>(this as PlayerInput, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerInput&&(identical(other.id, id) || other.id == id)&&(identical(other.score, score) || other.score == score)&&(identical(other.chip, chip) || other.chip == chip)&&(identical(other.specialPrizePt, specialPrizePt) || other.specialPrizePt == specialPrizePt));
}


@override
int get hashCode => Object.hash(runtimeType,id,score,chip,specialPrizePt);

@override
String toString() {
  return 'PlayerInput(id: $id, score: $score, chip: $chip, specialPrizePt: $specialPrizePt)';
}


}

/// @nodoc
abstract mixin class $PlayerInputCopyWith<$Res>  {
  factory $PlayerInputCopyWith(PlayerInput value, $Res Function(PlayerInput) _then) = _$PlayerInputCopyWithImpl;
@useResult
$Res call({
 int id, int score, int chip, int specialPrizePt
});




}
/// @nodoc
class _$PlayerInputCopyWithImpl<$Res>
    implements $PlayerInputCopyWith<$Res> {
  _$PlayerInputCopyWithImpl(this._self, this._then);

  final PlayerInput _self;
  final $Res Function(PlayerInput) _then;

/// Create a copy of PlayerInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? score = null,Object? chip = null,Object? specialPrizePt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,chip: null == chip ? _self.chip : chip // ignore: cast_nullable_to_non_nullable
as int,specialPrizePt: null == specialPrizePt ? _self.specialPrizePt : specialPrizePt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PlayerInput].
extension PlayerInputPatterns on PlayerInput {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayerInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayerInput() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayerInput value)  $default,){
final _that = this;
switch (_that) {
case _PlayerInput():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayerInput value)?  $default,){
final _that = this;
switch (_that) {
case _PlayerInput() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int score,  int chip,  int specialPrizePt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerInput() when $default != null:
return $default(_that.id,_that.score,_that.chip,_that.specialPrizePt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int score,  int chip,  int specialPrizePt)  $default,) {final _that = this;
switch (_that) {
case _PlayerInput():
return $default(_that.id,_that.score,_that.chip,_that.specialPrizePt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int score,  int chip,  int specialPrizePt)?  $default,) {final _that = this;
switch (_that) {
case _PlayerInput() when $default != null:
return $default(_that.id,_that.score,_that.chip,_that.specialPrizePt);case _:
  return null;

}
}

}

/// @nodoc


class _PlayerInput implements PlayerInput {
  const _PlayerInput({required this.id, this.score = 0, this.chip = 0, this.specialPrizePt = 0});
  

@override final  int id;
@override@JsonKey() final  int score;
@override@JsonKey() final  int chip;
@override@JsonKey() final  int specialPrizePt;

/// Create a copy of PlayerInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerInputCopyWith<_PlayerInput> get copyWith => __$PlayerInputCopyWithImpl<_PlayerInput>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerInput&&(identical(other.id, id) || other.id == id)&&(identical(other.score, score) || other.score == score)&&(identical(other.chip, chip) || other.chip == chip)&&(identical(other.specialPrizePt, specialPrizePt) || other.specialPrizePt == specialPrizePt));
}


@override
int get hashCode => Object.hash(runtimeType,id,score,chip,specialPrizePt);

@override
String toString() {
  return 'PlayerInput(id: $id, score: $score, chip: $chip, specialPrizePt: $specialPrizePt)';
}


}

/// @nodoc
abstract mixin class _$PlayerInputCopyWith<$Res> implements $PlayerInputCopyWith<$Res> {
  factory _$PlayerInputCopyWith(_PlayerInput value, $Res Function(_PlayerInput) _then) = __$PlayerInputCopyWithImpl;
@override @useResult
$Res call({
 int id, int score, int chip, int specialPrizePt
});




}
/// @nodoc
class __$PlayerInputCopyWithImpl<$Res>
    implements _$PlayerInputCopyWith<$Res> {
  __$PlayerInputCopyWithImpl(this._self, this._then);

  final _PlayerInput _self;
  final $Res Function(_PlayerInput) _then;

/// Create a copy of PlayerInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? score = null,Object? chip = null,Object? specialPrizePt = null,}) {
  return _then(_PlayerInput(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,score: null == score ? _self.score : score // ignore: cast_nullable_to_non_nullable
as int,chip: null == chip ? _self.chip : chip // ignore: cast_nullable_to_non_nullable
as int,specialPrizePt: null == specialPrizePt ? _self.specialPrizePt : specialPrizePt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$PlayerResult {

 int get id; double get basePoint; int get roundedPoint; int get finalPoint; int get money;
/// Create a copy of PlayerResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerResultCopyWith<PlayerResult> get copyWith => _$PlayerResultCopyWithImpl<PlayerResult>(this as PlayerResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerResult&&(identical(other.id, id) || other.id == id)&&(identical(other.basePoint, basePoint) || other.basePoint == basePoint)&&(identical(other.roundedPoint, roundedPoint) || other.roundedPoint == roundedPoint)&&(identical(other.finalPoint, finalPoint) || other.finalPoint == finalPoint)&&(identical(other.money, money) || other.money == money));
}


@override
int get hashCode => Object.hash(runtimeType,id,basePoint,roundedPoint,finalPoint,money);

@override
String toString() {
  return 'PlayerResult(id: $id, basePoint: $basePoint, roundedPoint: $roundedPoint, finalPoint: $finalPoint, money: $money)';
}


}

/// @nodoc
abstract mixin class $PlayerResultCopyWith<$Res>  {
  factory $PlayerResultCopyWith(PlayerResult value, $Res Function(PlayerResult) _then) = _$PlayerResultCopyWithImpl;
@useResult
$Res call({
 int id, double basePoint, int roundedPoint, int finalPoint, int money
});




}
/// @nodoc
class _$PlayerResultCopyWithImpl<$Res>
    implements $PlayerResultCopyWith<$Res> {
  _$PlayerResultCopyWithImpl(this._self, this._then);

  final PlayerResult _self;
  final $Res Function(PlayerResult) _then;

/// Create a copy of PlayerResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? basePoint = null,Object? roundedPoint = null,Object? finalPoint = null,Object? money = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,basePoint: null == basePoint ? _self.basePoint : basePoint // ignore: cast_nullable_to_non_nullable
as double,roundedPoint: null == roundedPoint ? _self.roundedPoint : roundedPoint // ignore: cast_nullable_to_non_nullable
as int,finalPoint: null == finalPoint ? _self.finalPoint : finalPoint // ignore: cast_nullable_to_non_nullable
as int,money: null == money ? _self.money : money // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PlayerResult].
extension PlayerResultPatterns on PlayerResult {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayerResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayerResult() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayerResult value)  $default,){
final _that = this;
switch (_that) {
case _PlayerResult():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayerResult value)?  $default,){
final _that = this;
switch (_that) {
case _PlayerResult() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  double basePoint,  int roundedPoint,  int finalPoint,  int money)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerResult() when $default != null:
return $default(_that.id,_that.basePoint,_that.roundedPoint,_that.finalPoint,_that.money);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  double basePoint,  int roundedPoint,  int finalPoint,  int money)  $default,) {final _that = this;
switch (_that) {
case _PlayerResult():
return $default(_that.id,_that.basePoint,_that.roundedPoint,_that.finalPoint,_that.money);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  double basePoint,  int roundedPoint,  int finalPoint,  int money)?  $default,) {final _that = this;
switch (_that) {
case _PlayerResult() when $default != null:
return $default(_that.id,_that.basePoint,_that.roundedPoint,_that.finalPoint,_that.money);case _:
  return null;

}
}

}

/// @nodoc


class _PlayerResult implements PlayerResult {
  const _PlayerResult({required this.id, required this.basePoint, required this.roundedPoint, required this.finalPoint, required this.money});
  

@override final  int id;
@override final  double basePoint;
@override final  int roundedPoint;
@override final  int finalPoint;
@override final  int money;

/// Create a copy of PlayerResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerResultCopyWith<_PlayerResult> get copyWith => __$PlayerResultCopyWithImpl<_PlayerResult>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerResult&&(identical(other.id, id) || other.id == id)&&(identical(other.basePoint, basePoint) || other.basePoint == basePoint)&&(identical(other.roundedPoint, roundedPoint) || other.roundedPoint == roundedPoint)&&(identical(other.finalPoint, finalPoint) || other.finalPoint == finalPoint)&&(identical(other.money, money) || other.money == money));
}


@override
int get hashCode => Object.hash(runtimeType,id,basePoint,roundedPoint,finalPoint,money);

@override
String toString() {
  return 'PlayerResult(id: $id, basePoint: $basePoint, roundedPoint: $roundedPoint, finalPoint: $finalPoint, money: $money)';
}


}

/// @nodoc
abstract mixin class _$PlayerResultCopyWith<$Res> implements $PlayerResultCopyWith<$Res> {
  factory _$PlayerResultCopyWith(_PlayerResult value, $Res Function(_PlayerResult) _then) = __$PlayerResultCopyWithImpl;
@override @useResult
$Res call({
 int id, double basePoint, int roundedPoint, int finalPoint, int money
});




}
/// @nodoc
class __$PlayerResultCopyWithImpl<$Res>
    implements _$PlayerResultCopyWith<$Res> {
  __$PlayerResultCopyWithImpl(this._self, this._then);

  final _PlayerResult _self;
  final $Res Function(_PlayerResult) _then;

/// Create a copy of PlayerResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? basePoint = null,Object? roundedPoint = null,Object? finalPoint = null,Object? money = null,}) {
  return _then(_PlayerResult(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,basePoint: null == basePoint ? _self.basePoint : basePoint // ignore: cast_nullable_to_non_nullable
as double,roundedPoint: null == roundedPoint ? _self.roundedPoint : roundedPoint // ignore: cast_nullable_to_non_nullable
as int,finalPoint: null == finalPoint ? _self.finalPoint : finalPoint // ignore: cast_nullable_to_non_nullable
as int,money: null == money ? _self.money : money // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
