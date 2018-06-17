<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="example_with_effects" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">

    <head>
        <!-- Descritores que definem COMO tocar-->
        <descriptorBase>
            <descriptor id="descBgImage" region="rgImage"/>
            <descriptor id="descCurtain" region="rgVideo"/>
            <descriptor id="dLua" region="rgLua" />
        </descriptorBase>

        <regionBase>
      <region id="rgLua" width="100%" height="100%"/>
      <region id="rgVideo" left="200" top="168" width="50%" height="50%" />
      <region id="rgImage" left="200" top="240" width="388" height="59" />

  </regionBase>
        <!-- Conectores que definem QUANDO tocar-->
        <connectorBase>
            <!-- quando X começar a tocar, altero a propriedade value de Y -->
            <causalConnector id="onBegin1SetN">
              <simpleAction role="set" value="$value" max="unbounded" qualifier="seq"/>
              <connectorParam name="value"/>
              <simpleCondition role="onBegin"/>
            </causalConnector>

            <causalConnector id="onKeySelectionStart">
                <connectorParam name="vKey"/>
                <simpleCondition role="onSelection" key="$vKey" />
                <simpleAction role="start" max="unbounded" qualifier="par" />
          </causalConnector>

        </connectorBase>
    </head>

    <body>
        <port id="pImage" component="bgImage" />

        <media id="bgImage" src="media/campfire.png" descriptor="descBgImage" />
        <media id="curtainVideo" src="media/wind.mp4" descriptor="descCurtain" />

        <media id="lightCurtain" SEtype="lightType">
            <property name="azimuthal" value="45" />
            <property name="polar" value="27.5" />
            <property name="width" value="0" />
            <property name="height" value="45" />
            <property name="intensity" value="50.0" />
            <property name="color" value="white" />
        </media>



     <media id="notSensoryEffect">
            <property name="volume" value="45" />
            <property name="middle" value="27.5" />
            <property name="times" value="45" />
        </media>


        <link xconnector="onKeySelectionStart">
           <bind role="onSelection" component="bgImage">
               <bindParam name="vKey" value="YELLOW" />
           </bind>
           <bind role="start" component="curtainVideo" />
           <bind role="start" component="lightCurtain" />
        </link>

        <link xconnector="onEndDoSomething">
           <bind role="onEnd" component="lightCurtain" />
           <bind role="start" component="myStuff" />
        </link>

        <link xconnector="onEndDoSomething">
           <bind role="onEnd" component="anotherLight" />
           <bind role="start" component="myStuff" />
        </link>

    </body>
</ncl>