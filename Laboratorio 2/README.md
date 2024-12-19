# Mi primer diseño 
1. **Dominio Comportamental(Especificación y Algoritmo)**
Se plantea inicilamente el comportamiento esperado por el sistema, utilizando como medio el diagrama de caja Negra, en el que se representan las entradas y salidas de infomación. En esta situación problema se plantean las siguientas entradas y salidas:

I0 = Red eléctrica (Sensor de fuente 1)

I1 = Banco de baterias (Sensor de fuente 2)

I2 = Energía solar (Sensor de Luz)

I3 = Boton de paro de emergencia 

Q0 = Relé de conmutación entre fuentes

Q1 = Relé para energizar o desenergizar 

Q2 = Indicador cuando las baterias estan descargadas

Q3 = Indicador de red eléctrica disponible

Q4 = Indicador de suficiente radiación solar

Q5 = Desenergización de la casa para mantenimiento

![Diagrama de Caja Negra](https://github.com/JeredyBeltran/Images/blob/main/Caja%20(2).png?raw=true)

Como siguiente paso, se propone la tabla de verdad considerando todos los posibles casos, en este punto hacemos uso de la condición Don't Care y las siguientes condiciones:

![Tabla de Verdad](https://github.com/JeredyBeltran/Images/blob/main/Tabla.png?raw=true)

* I0: 0=no hay red, 1=hay red
* I1: 0=bateria descargada, 1=bateria cargada
* I2: 0=no hay energía solar, 1=hay energía solar
* I3: 0=no esta activo, 1=esta activo
* Q0: 0=Conmutación a red eléctrica, 1=Conmutación al banco de baterias
* Q1: 0=Casa energizada, 1=Casa desenergizada
* Q2: 0=bateria  descargada, 1=bateria cargada
* Q3: 0=no hay red, 1=hay red
* Q4: 0=hay suficiente energia solar, 1= no hay
* Q5: 0=esta en paro de emergencia, 1=no esta en paro de emergencia

![Diagrame de flujo](https://github.com/JeredyBeltran/Images/blob/main/Diagrama.png?raw=true)
