# Desarrollo de laboratorio 1
## Parte 1: Comparar las especificaciones técnicas de cada dispositivo
# Comparación: Negador TTL 74LS04 vs Negador CMOS CD4069

A continuación, se muestra una tabla con las principales diferencias técnicas:

| Característica                         | 74LS04 (TTL)                                            | CD4069 (CMOS)                                          |
|----------------------------------------|---------------------------------------------------------|--------------------------------------------------------|
| **Tecnología de fabricación**          | TTL (Transistor-Transistor Logic)                       | CMOS (Complementary Metal-Oxide-Semiconductor)         |
| **Voltaje de operación (Vcc)**         | 4.75V a 5.25V                                           | 3V a 15V                                               |
| **Consumo de corriente**               | Mayor consumo de energía debido a la tecnología TTL     | Menor consumo de energía gracias a la tecnología CMOS  |
| **Tiempo de propagación**              | Aproximadamente 10 ns                                   | Aproximadamente 50 ns                                  |
| **Margen de ruido**                    | Menor margen de ruido                                   | Mayor inmunidad al ruido                               |
| **Capacidad de corriente de salida**   | Puede hundir hasta 8 mA y suministrar 0.4 mA              | Puede hundir o suministrar hasta 4 mA                  |
| **Rango de temperatura de operación**  | 0°C a 70°C                                              | -55°C a 125°C                                          |


## Parte 2: Circuitos equivalentes de cada negador en TTL y CMOS
 - TTL

![TTL](./TTL1.png)

- CMOS
![TTL](./CMOS1.png)

## Señal cuadrada para medir tensión


## Parte 2: 
1. Determinar el fan-in y fan-out de cada uno de los dispositivos.
2. Determinar la disipación de potencia.
3. Proponer e implementar un circuito de entrada y de salida para cada uno de los dispositivos teniendo en cuenta los parámetros de cada tecnología para observar el comportamiento del mismo.


## Parte 2: 




### Comparación de Datos Experimentales Vs. Teóricos

| Parámetro                      | Experimental (TTL)  | Teórico (TTL)   | Diferencia           | Experimental (CMOS) | Teórico (CMOS)      | Diferencia         |
|--------------------------------|---------------------|-----------------|----------------------|---------------------|---------------------|--------------------|
| tPLH (Low → High)              | 13 ns              | 10 - 20 ns      | Dentro del rango     | 100 ns              | 50 - 200 ns         | Dentro del rango   |
| tPHL (High → Low)              | 19 ns              | 10 - 20 ns      | Dentro del rango     | 120 ns              | 50 - 200 ns         | Dentro del rango   |
| tr (Tiempo de subida)          | 22.8 ns            | < 25 ns         | Dentro del rango     | 5.36 µs             | 100 ns - µs         | En el rango alto   |
| tf (Tiempo de bajada)          | 26 ns              | < 25 ns         | Ligeramente alto     | 6.48 µs             | 100 ns - µs         | En el rango alto   |
| Tiempo de propagación (out)    | 49 ns (TPLH) 39 ns (TPHL) | No especificado | N/A                  | 780 ns (TPLH) 940 ns (TPHL) | No especificado | N/A                |
| talm (Tiempo de alineación)    | 12 ns              | No disponible   | N/A                  | 840 ns              | No disponible       | N/A                |
| VIL (Voltaje Bajo de Entrada)  | 2.08 V             | 0.8 V           | Mayor de lo esperado | 1.67 V              | 1/3 VDD (≈1.67 V a 5V) | Dentro del rango   |
| VIH (Voltaje Alto de Entrada)  | 3.47 V             | 2 V             | Mayor de lo esperado | 2.72 V              | 2/3 VDD (≈3.33 V a 5V) | Lig. menor         |

## Parte 3: 
1. El oscilador en anillo es un circuito compuesto por compiertas NOT que se utiliza para generar señales una señal peródica sin necesidad de componentes externos.
En esencia, este oscilador se forma conectando en serie un número impar de compuertas inversoras (NOT), de modo que la saliada de la última compuerta se retroalimente a la entrada de la primera. Por el funcinamiento intrínseco de la compuerta NOT, esta empezará oscilar. Se necesita un número impar de inversores para que la señal no se estabilice, y cambie continuamente de estado. La frecuencia se determina utilizando el retardo de propagación de cada compuerta, sumándose entre sí conforme se agregan más compuertas. 

