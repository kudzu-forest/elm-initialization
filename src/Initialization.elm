module Initialization exposing
    ( Program
    , element, document
    , accumulate
    )

{-| This module provides a simplified way to separate the initialization process of an application,
where random values have not yet been generated, HTTP responses have not yet arrived, and so on.

By using this module, you can define two model types:
one that exists only during the initialization phase,
and another that exists only during the running phase.
This helps you avoid flooding your model with `Maybe` values
that are needed only to represent the absence of data during initialization.

If you find these functionalities too restricted,
check the `Initialization.Advanced` module for more control.


# Type

@docs Program


# Functions

@docs element, document


# Helper

@docs accumulate

-}

import Browser
import Html exposing (Html)
import Initialization.Advanced as I
import Task


{-| A type alias for `Platform.Program flag <internally defined model type> <internally defined msg type>`.

This type is intended to be used in the type annotation of the `main` function.

-}
type alias Program flag initializingModel runningModel msg =
    I.Program flag initializingModel (initializingModel -> initializingModel) runningModel msg


{-| Similar to `Browser.element`, but with more flexibility during the initialization process.

In the first argument record, you define the initialization phase with its own model type,
`initializingModel`.
The `Cmd (initializingModel -> initializingModel)` value returned from the function assigned
to the `init` field describes how `initializingModel` values should be transformed
by effectful commands.
(Use `Cmd.batch` to execute multiple commands. Note that their execution order is not guaranteed.)

`toRunning` is called every time `initializingModel` is updated.
If it returns `Ok ( runningModel, runningMsgCmd )`,
the initialization phase ends immediately,
and the running phase defined by the second argument record begins,
as if `( runningModel, runningMsgCmd )` were returned from the `init` function
of a normal `Browser.element`.

With `blockingReason` values,
you can represent why the initialization phase is still in progress
and the running phase has not yet started.
For simple use cases, the `blockingReason` type can just be `String`,
but you may also use a custom type to represent richer, structured reasons.
These values are returned by `toRunning` when it fails to convert
`initializingModel` into `( runningModel, Cmd runningMsg )`,
and are passed to `initView` so that you can display the current state
to users of your web application.

⚠️ If `toRunning` returns `Ok _`, the initialization phase ends immediately,
and any remaining `Cmd (initializingModel -> initializingModel)` values are ignored.
Be careful not to return `Ok _` while waiting for indispensable command results,
such as those from an HTTP request.

If you need more advanced control, see `Initialization.Advanced.element`, which allows:

  - dynamic creation of `Cmd` values during the initialization phase
  - controlling the execution order of commands, as in normal TEA applications

-}
element :
    { init : flag -> ( initializingModel, Cmd (initializingModel -> initializingModel) )
    , initView : List blockingReason -> initializingModel -> Html (initializingModel -> initializingModel)
    , toRunning : initializingModel -> Result (List blockingReason) ( model, Cmd msg )
    }
    ->
        { subscriptions : model -> Sub msg
        , update : msg -> model -> ( model, Cmd msg )
        , view : model -> Html msg
        }
    -> Program flag initializingModel model msg
element { init, initView, toRunning } =
    I.element
        { init = init
        , initSubscriptions = \_ -> Sub.none
        , initUpdate =
            \f iModel ->
                ( f iModel, Cmd.none )
        , initView =
            \blockingReasons initializingModel -> initView blockingReasons initializingModel
        , toRunning = toRunning
        }


{-| Similar to `Browser.document`, but with more flexibility during the initialization process.

In the first argument record, you define the initialization phase with its own model type,
`initializingModel`.
The `Cmd (initializingModel -> initializingModel)` value returned from the function assigned
to the `init` field describes how `initializingModel` values should be transformed
by effectful commands.
(Use `Cmd.batch` to execute multiple commands. Note that their execution order is not guaranteed.)

`toRunning` is called every time `initializingModel` is updated.
If it returns `Ok ( runningModel, runningMsgCmd )`,
the initialization phase ends immediately,
and the running phase defined by the second argument record begins,
as if `( runningModel, runningMsgCmd )` were returned from the `init` function
of a normal `Browser.document`.

With `blockingReason` values,
you can represent why the initialization phase is still in progress
and the running phase has not yet started.
For simple use cases, the `blockingReason` type can just be `String`,
but you may also use a custom type to represent richer, structured reasons.
These values are returned by `toRunning` when it fails to convert
`initializingModel` into `( runningModel, Cmd runningMsg )`,
and are passed to `initView` so that you can display the current state
to users of your web application.

⚠️ If `toRunning` returns `Ok _`, the initialization phase ends immediately,
and any remaining `Cmd (initializingModel -> initializingModel)` values are ignored.
Be careful not to return `Ok _` while waiting for indispensable command results,
such as those from an HTTP request.

If you need more advanced control, see `Initialization.Advanced.document`, which allows:

  - dynamic creation of `Cmd` values during the initialization phase
  - controlling the execution order of commands, as in normal TEA applications

-}
document :
    { init : flag -> ( initializingModel, Cmd (initializingModel -> initializingModel) )
    , initView : List blockingReason -> initializingModel -> Browser.Document (initializingModel -> initializingModel)
    , toRunning : initializingModel -> Result (List blockingReason) ( model, Cmd msg )
    }
    ->
        { subscriptions : model -> Sub msg
        , update : msg -> model -> ( model, Cmd msg )
        , view : model -> Browser.Document msg
        }
    -> Program flag initializingModel model msg
document { init, initView, toRunning } =
    I.document
        { init = init
        , initSubscriptions = \_ -> Sub.none
        , initUpdate =
            \f iModel ->
                ( f iModel, Cmd.none )
        , initView =
            \blockingReasons initializingModel -> initView blockingReasons initializingModel
        , toRunning = toRunning
        }


{-| An applicative-style helper that accumulates blocking reasons.

    toRunning : { mTimezone : Maybe Time.Zone, mPosixTime : Maybe Time.Posix } -> Result (List String) ( { timezone : Time.Zone, posixTime : Time.Posix }, Cmd msg )
    toRunning { mTimezone, mPosixTime } =
        Ok (\timezone posixTime -> { timezone = timezone, posixTime = posixTime })
            |> accumulate (Result.fromMaybe "No timezone" mTimezone)
            |> accumulate (Result.fromMaybe "No posix time" mPosixTime)

-}
accumulate : Result blockingReason a -> Result (List blockingReason) (a -> b) -> Result (List blockingReason) b
accumulate =
    I.accumulate
