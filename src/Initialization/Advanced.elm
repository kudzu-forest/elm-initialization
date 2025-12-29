module Initialization.Advanced exposing
    ( Program
    , element, document
    , accumulate
    )

{-| This module provides whole control over the initialization process.

For most applications, the simpler `Initialization.element` API is sufficient.
Use this module only if you need finer control over the initialization phase,
such as dynamic command creation.

What you do with this module is basically to define two independent TEA application,
one representing initializing process and the other running process,
and to define one conversion function from initializing model to running model.


# Type

@docs Program


# Functions

@docs element, document


# Helper

@docs accumulate

-}

import Browser
import Html


type Model initializing running
    = Initializing initializing
    | Running running


type Msg initializingMsg runningMsg
    = InitializingMsg initializingMsg
    | RunningMsg runningMsg


{-| A type alias for `Platform.Program flag <internally defined model type> <internally defined msg type>`.

This type is intended to be used in the type annotation of the `main` function.

-}
type alias Program flag initializingModel initializingMsg runningModel runningMsg =
    Platform.Program flag (Model initializingModel runningModel) (Msg initializingMsg runningMsg)


{-| Similar to `Browser.element`, but with more flexibility during the initialization process.

In the first argument record, you define the initialization phase in the same way as a normal TEA element.
Here, `toRunning` is called every time `initializingModel` is updated.
When it returns `Ok ( runningModel, runningMsgCmd )`, the initialization phase is terminated,
and the running phase defined by the second argument record begins,
as if `( runningModel, runningMsgCmd )` were returned from the `init` function
in an ordinary `Browser.element` argument record.

By introducing the `blockingReason` type,
you can represent the reason why the initialization phase is still in progress
and the running phase has not yet started.
This value is returned by `toRunning` when it fails to convert `initializingModel`
to `( runningModel, Cmd runningMsg )`,
and is used by `initView` to display the current state to users of your web application.

⚠️ If `toRunning` returns `Ok _`, the initialization phase is forced to end,
and any remaining `Cmd initializingMsg` values are ignored.
Be careful not to return `Ok _` while waiting for command results that are indispensable for your app,
such as an HTTP request.

-}
element :
    { init : flag -> ( initializingModel, Cmd initializingMsg )
    , initSubscriptions : initializingModel -> Sub initializingMsg
    , initUpdate : initializingMsg -> initializingModel -> ( initializingModel, Cmd initializingMsg )
    , initView : List blockingReason -> initializingModel -> Html.Html initializingMsg
    , toRunning : initializingModel -> Result (List blockingReason) ( runningModel, Cmd runningMsg )
    }
    ->
        { subscriptions : runningModel -> Sub runningMsg
        , update : runningMsg -> runningModel -> ( runningModel, Cmd runningMsg )
        , view : runningModel -> Html.Html runningMsg
        }
    -> Program flag initializingModel initializingMsg runningModel runningMsg
element { init, initSubscriptions, initUpdate, initView, toRunning } { subscriptions, update, view } =
    Browser.element
        { init =
            \flag ->
                let
                    ( initialInitializationModel, initialCmd ) =
                        init flag
                in
                case toRunning initialInitializationModel of
                    Err _ ->
                        ( Initializing initialInitializationModel, Cmd.map InitializingMsg initialCmd )

                    Ok ( rModel, rCmd ) ->
                        ( Running rModel, Cmd.map RunningMsg rCmd )
        , subscriptions =
            \model ->
                case model of
                    Initializing iModel ->
                        Sub.map InitializingMsg (initSubscriptions iModel)

                    Running rModel ->
                        Sub.map RunningMsg (subscriptions rModel)
        , update =
            \msg model ->
                case msg of
                    RunningMsg rMsg ->
                        case model of
                            Running rModel ->
                                let
                                    ( newRunningModel, newRunningCmd ) =
                                        update rMsg rModel
                                in
                                ( Running newRunningModel, Cmd.map RunningMsg newRunningCmd )

                            _ ->
                                -- impossible
                                ( model, Cmd.none )

                    InitializingMsg iMsg ->
                        case model of
                            Initializing iModel ->
                                let
                                    ( newInitModel, newInitCmd ) =
                                        initUpdate iMsg iModel
                                in
                                case toRunning newInitModel of
                                    Err blockingReasons ->
                                        ( Initializing newInitModel, Cmd.map InitializingMsg newInitCmd )

                                    Ok ( rModel, rCmd ) ->
                                        ( Running rModel, Cmd.map RunningMsg rCmd )

                            _ ->
                                -- impossible
                                ( model, Cmd.none )
        , view =
            \model ->
                case model of
                    Initializing iModel ->
                        case toRunning iModel of
                            Err blockingReasons ->
                                Html.map InitializingMsg (initView blockingReasons iModel)

                            Ok _ ->
                                Html.map InitializingMsg (initView [] iModel)

                    Running rModel ->
                        Html.map RunningMsg (view rModel)
        }


{-| Similar to `Browser.document`, but with more flexibility during the initialization process.

In the first argument record, you define the initialization phase in the same way as a normal TEA document.
Here, `toRunning` is called every time `initializingModel` is updated.
When it returns `Ok ( runningModel, runningMsgCmd )`, the initialization phase is terminated,
and the running phase defined by the second argument record begins,
as if `( runningModel, runningMsgCmd )` were returned from the `init` function
in an ordinary `Browser.document` argument record.

By introducing the `blockingReason` type,
you can represent the reason why the initialization phase is still in progress
and the running phase has not yet started.
This value is returned by `toRunning` when it fails to convert `initializingModel`
to `( runningModel, Cmd runningMsg )`,
and is used by `initView` to display the current state to users of your web application.

⚠️ If `toRunning` returns `Ok _`, the initialization phase is forced to end,
and any remaining `Cmd initializingMsg` values are ignored.
Be careful not to return `Ok _` while waiting for command results that are indispensable for your app,
such as an HTTP request.

-}
document :
    { init : flag -> ( initializingModel, Cmd initializingMsg )
    , initSubscriptions : initializingModel -> Sub initializingMsg
    , initUpdate : initializingMsg -> initializingModel -> ( initializingModel, Cmd initializingMsg )
    , initView : List blockingReason -> initializingModel -> Browser.Document initializingMsg
    , toRunning : initializingModel -> Result (List blockingReason) ( runningModel, Cmd runningMsg )
    }
    ->
        { subscriptions : runningModel -> Sub runningMsg
        , update : runningMsg -> runningModel -> ( runningModel, Cmd runningMsg )
        , view : runningModel -> Browser.Document runningMsg
        }
    -> Program flag initializingModel initializingMsg runningModel runningMsg
document { init, initSubscriptions, initUpdate, initView, toRunning } { subscriptions, update, view } =
    Browser.document
        { init =
            \flag ->
                let
                    ( initialInitializationModel, initialCmd ) =
                        init flag
                in
                case toRunning initialInitializationModel of
                    Err _ ->
                        ( Initializing initialInitializationModel, Cmd.map InitializingMsg initialCmd )

                    Ok ( rModel, rCmd ) ->
                        ( Running rModel, Cmd.map RunningMsg rCmd )
        , subscriptions =
            \model ->
                case model of
                    Initializing iModel ->
                        Sub.map InitializingMsg (initSubscriptions iModel)

                    Running rModel ->
                        Sub.map RunningMsg (subscriptions rModel)
        , update =
            \msg model ->
                case msg of
                    RunningMsg rMsg ->
                        case model of
                            Running rModel ->
                                let
                                    ( newRunningModel, newRunningCmd ) =
                                        update rMsg rModel
                                in
                                ( Running newRunningModel, Cmd.map RunningMsg newRunningCmd )

                            _ ->
                                -- impossible
                                ( model, Cmd.none )

                    InitializingMsg iMsg ->
                        case model of
                            Initializing iModel ->
                                let
                                    ( newInitModel, newInitCmd ) =
                                        initUpdate iMsg iModel
                                in
                                case toRunning newInitModel of
                                    Err blockingReasons ->
                                        ( Initializing newInitModel, Cmd.map InitializingMsg newInitCmd )

                                    Ok ( rModel, rCmd ) ->
                                        ( Running rModel, Cmd.map RunningMsg rCmd )

                            _ ->
                                -- impossible
                                ( model, Cmd.none )
        , view =
            \model ->
                case model of
                    Initializing iModel ->
                        case toRunning iModel of
                            Err blockingReasons ->
                                let
                                    { title, body } =
                                        initView blockingReasons iModel
                                in
                                { title = title
                                , body = List.map (Html.map InitializingMsg) body
                                }

                            Ok _ ->
                                let
                                    { title, body } =
                                        initView [] iModel
                                in
                                { title = title
                                , body = List.map (Html.map InitializingMsg) body
                                }

                    Running rModel ->
                        let
                            { title, body } =
                                view rModel
                        in
                        { title = title
                        , body = List.map (Html.map RunningMsg) body
                        }
        }


{-| An applicative-style helper that accumulates blocking reasons.
Blocking reasons are accumulated in reverse order of application.

    type alias InitializingModel =
        { mTimezone : Maybe Time.Zone
        , mPosixTime : Maybe Time.Posix
        }

    type alias Model =
        { timezone : Time.Zone
        , posixTime : Time.Posix
        }

    toRunning : InitializingModel -> Result (List String) ( Model, Cmd msg )
    toRunning { mTimezone, mPosixTime } =
        Ok (\timezone posixTime -> ( { timezone = timezone, posixTime = posixTime }, Cmd.none ))
            |> accumulate (Result.fromMaybe "No timezone" mTimezone)
            |> accumulate (Result.fromMaybe "No posix time" mPosixTime)

    toRunning (InitializingModel Nothing Nothing)
        --> Err ["No posix time", "No timezone"]

-}
accumulate : Result blockingReason a -> Result (List blockingReason) (a -> b) -> Result (List blockingReason) b
accumulate ra rf =
    case rf of
        Err reasons ->
            case ra of
                Err reason ->
                    Err (reason :: reasons)

                Ok _ ->
                    Err reasons

        Ok f ->
            case ra of
                Err reason ->
                    Err [ reason ]

                Ok a ->
                    Ok (f a)
