module Initialization.Debuggable exposing (Program, accumulate, document, element, toDebuggable, toDebuggableCmd)

{-| This module enables you to prepare more precise debugging information
than the `Initialization` module.

The information provided by this module is available only when you compile
your application with `elm make --debug`.

When you use the `Initialization` module, the information shown in the Elm
Debugger during the initializing phase is often surprisingly poor.
This is because all `Msg` values in that phase are model-transforming functions,
which the debugger can only display as `<internals>`.

By using this module, you can:

  - add `String` descriptions to each model-transforming function returned by commands
  - inspect additional information when a transformation is executed, based on the `initializingModel` values before and after the transformation


# How to Migrate from the `Initialization` Module

1.  Change `import Initialization as Init`
    to `import Initialization.Debuggable as Init`.
    Using the same alias saves time and effort.

2.  Add `Init.toDebuggableCmd "" (always Nothing)`
    before each `Cmd` value passed to `Cmd.batch` in your `init` function.

3.  Add `Init.toDebuggable "" (always Nothing)`
    before each model-transforming function in the `Html` value returned
    from the `initView` function.

4.  Fill in the empty string arguments (`""`) with descriptions as needed.

5.  Replace any of the `(always Nothing)` functions with
    `({ old : initializingModel, new : initializingModel } -> updateInfo)`,
    where `updateInfo` is any type you define.
    Wrapping the value in `Just` is usually sufficient.


# Example Code

The code below demonstrates how to debug Posix time initialization.

    import Html
    import Initialization.Debuggable as Init
    import Task
    import Time

    type InitUpdateInfo
        = PosixTimeUpdated { old : Maybe Time.Posix, new : Maybe Time.Posix }

    type Msg
        = Tick Time.Posix

    main : Init.Program () { mTimezone : Maybe Time.Zone, mPosixTime : Maybe Time.Posix } InitUpdateInfo { timezone : Time.Zone, posixTime : Time.Posix } Msg
    main =
        Init.element
            { init =
                \() ->
                    ( { mTimezone = Nothing
                      , mPosixTime = Nothing
                      }
                    , Cmd.batch
                        [ Init.toDebuggableCmd ""
                            (always Nothing)
                            (Task.perform (\tz im -> { im | mTimezone = Just tz }) Time.here)
                        , Init.toDebuggableCmd "updating posix time"
                            (\{ old, new } -> PosixTimeUpdated { old = old.mPosixTime, new = new.mPosixTime })
                            (Task.perform (\pt im -> { im | mPosixTime = Just pt }) Time.now)
                        ]
                    )
            , initView =
                \blockingReasons iModel -> Html.div [] (List.map Html.text blockingReasons |> List.intersperse (Html.br [] []))
            , toRunning =
                \{ mTimezone, mPosixTime } ->
                    Ok (\tz pt -> ( { timezone = tz, posixTime = pt }, Cmd.none ))
                        |> Init.accumulate
                            (Result.fromMaybe "No timezone" mTimezone)
                        |> Init.accumulate
                            (Result.fromMaybe "No posixTime" mPosixTime)
            }
            { subscriptions =
                \_ -> Time.every 1000 Tick
            , update =
                \msg model ->
                    case msg of
                        Tick pt ->
                            ( { model | posixTime = pt }, Cmd.none )
            , view =
                \{ timezone, posixTime } ->
                    Html.text <|
                        String.fromInt (Time.toHour timezone posixTime)
                            ++ " : "
                            ++ String.fromInt (Time.toMinute timezone posixTime)
                            ++ " : "
                            ++ String.fromInt (Time.toSecond timezone posixTime)
            }

-}

import Browser
import Html exposing (Html)
import Initialization.Advanced as I
import Task


{-| `Msg` type used internally to represent model-transforming steps during the initializing phase.
-}
type MsgWithInfo initUpdateInfo initializingModel
    = TransformFunctionArrived
        { description : String
        , toUpdateInfo : { old : initializingModel, new : initializingModel } -> initUpdateInfo
        , transform : initializingModel -> initializingModel
        }
    | TransformExecuted
        { description : String
        , updateInfo : initUpdateInfo
        }


{-| Type alias for `Platform.Program flag <internally defined Model type> <internally defined Msg type>`.
-}
type alias Program flag initializingModel initUpdateInfo runningModel runningMsg =
    I.Program flag initializingModel (MsgWithInfo initUpdateInfo initializingModel) runningModel runningMsg


initUpdate : MsgWithInfo initUpdateInfo initializingModel -> initializingModel -> ( initializingModel, Cmd (MsgWithInfo initUpdateInfo initializingModel) )
initUpdate iMsg iModel =
    case iMsg of
        TransformFunctionArrived { description, toUpdateInfo, transform } ->
            let
                newModel =
                    transform iModel
            in
            ( newModel
            , Task.perform identity
                (Task.succeed
                    (TransformExecuted
                        { description = description
                        , updateInfo = toUpdateInfo { old = iModel, new = newModel }
                        }
                    )
                )
            )

        TransformExecuted _ ->
            ( iModel, Cmd.none )


{-| Converts `Cmd (initializingModel -> initializingModel)`
into `Cmd (MsgWithInfo updateInfo initializingModel)`.

This function is intended to be used in the `init` function.

-}
toDebuggableCmd :
    String
    -> ({ old : initializingModel, new : initializingModel } -> initUpdateInfo)
    -> Cmd (initializingModel -> initializingModel)
    -> Cmd (MsgWithInfo initUpdateInfo initializingModel)
toDebuggableCmd description toUpdateInfo =
    Cmd.map
        (\transform ->
            TransformFunctionArrived
                { description = description
                , toUpdateInfo = toUpdateInfo
                , transform = transform
                }
        )


{-| Converts `initializingModel -> initializingModel`
into `MsgWithInfo updateInfo initializingModel`.

This function is intended to be used in the `initView` function.

-}
toDebuggable :
    String
    -> ({ old : initializingModel, new : initializingModel } -> initUpdateInfo)
    -> (initializingModel -> initializingModel)
    -> MsgWithInfo initUpdateInfo initializingModel
toDebuggable description toUpdateInfo transform =
    TransformFunctionArrived
        { description = description
        , toUpdateInfo = toUpdateInfo
        , transform = transform
        }


{-| Similar to `Initialization.element`, but requires that all `Msg` values
are converted from `initializingModel -> initializingModel`
into `MsgWithInfo initUpdateInfo initializingModel`
using `toDebuggableCmd` and `toDebuggable`.
-}
element :
    { init : flag -> ( initializingModel, Cmd (MsgWithInfo initUpdateInfo initializingModel) )
    , initView : List blockingReason -> initializingModel -> Html (MsgWithInfo initUpdateInfo initializingModel)
    , toRunning : initializingModel -> Result (List blockingReason) ( runningModel, Cmd runningMsg )
    }
    ->
        { subscriptions : runningModel -> Sub runningMsg
        , update : runningMsg -> runningModel -> ( runningModel, Cmd runningMsg )
        , view : runningModel -> Html runningMsg
        }
    -> Program flag initializingModel initUpdateInfo runningModel runningMsg
element { init, initView, toRunning } =
    I.element
        { init = init
        , initSubscriptions = \_ -> Sub.none
        , initUpdate = initUpdate
        , initView = initView
        , toRunning = toRunning
        }


{-| Similar to `Initialization.document`, but requires that all `Msg` values
are converted from `initializingModel -> initializingModel`
into `MsgWithInfo initUpdateInfo initializingModel`
using `toDebuggableCmd` and `toDebuggable`.
-}
document :
    { init : flag -> ( initializingModel, Cmd (MsgWithInfo initUpdateInfo initializingModel) )
    , initView : List blockingReason -> initializingModel -> Browser.Document (MsgWithInfo initUpdateInfo initializingModel)
    , toRunning : initializingModel -> Result (List blockingReason) ( runningModel, Cmd runningMsg )
    }
    ->
        { subscriptions : runningModel -> Sub runningMsg
        , update : runningMsg -> runningModel -> ( runningModel, Cmd runningMsg )
        , view : runningModel -> Browser.Document runningMsg
        }
    -> Program flag initializingModel initUpdateInfo runningModel runningMsg
document { init, initView, toRunning } =
    I.document
        { init = init
        , initSubscriptions = \_ -> Sub.none
        , initUpdate = initUpdate
        , initView = initView
        , toRunning = toRunning
        }


{-| The same as `Initialization.accumulate`.
-}
accumulate : Result blockingReason a -> Result (List blockingReason) (a -> b) -> Result (List blockingReason) b
accumulate =
    I.accumulate
