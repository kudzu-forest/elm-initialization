module Initialization.Debuggable exposing (Program, accumulate, element, toDebuggable, toDebuggableCmd)

import Html exposing (Html)
import Initialization.Advanced as I
import Task


type MsgWithInfo initUpdateInfo initializingModel
    = TransformFunctionArrived String ({ old : initializingModel, new : initializingModel } -> initUpdateInfo) (initializingModel -> initializingModel)
    | TransformExecuted
        { description : String
        , updateInfo : initUpdateInfo
        }


type alias Program flag initializingModel initUpdateInfo runningModel runningMsg =
    I.Program flag initializingModel (MsgWithInfo initUpdateInfo initializingModel) runningModel runningMsg


initUpdate : MsgWithInfo initUpdateInfo initializingModel -> initializingModel -> ( initializingModel, Cmd (MsgWithInfo initUpdateInfo initializingModel) )
initUpdate iMsg iModel =
    case iMsg of
        TransformFunctionArrived description toUpdateInfo transform ->
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


toDebuggableCmd :
    String
    -> ({ old : initializingModel, new : initializingModel } -> initUpdateInfo)
    -> Cmd (initializingModel -> initializingModel)
    -> Cmd (MsgWithInfo initUpdateInfo initializingModel)
toDebuggableCmd description toUpdateInfo =
    Cmd.map (TransformFunctionArrived description toUpdateInfo)


toDebuggable :
    String
    -> ({ old : initializingModel, new : initializingModel } -> initUpdateInfo)
    -> (initializingModel -> initializingModel)
    -> MsgWithInfo initUpdateInfo initializingModel
toDebuggable =
    TransformFunctionArrived


{-|

    import Html
    import Initialization.Debuggable as Init
    import Task
    import Time

    type InitUpdateInfo
        = NoInfo
        | PosixTimeUpdated { old : Maybe Time.Posix, new : Maybe Time.Posix }

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
                        [ Init.toDebuggableCmd "updating timezone"
                            (\_ -> NoInfo)
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


accumulate : Result blockingReason a -> Result (List blockingReason) (a -> b) -> Result (List blockingReason) b
accumulate =
    I.accumulate
