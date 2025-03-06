# Diseño de un voltímetro de Vp (tensión pico) para una red monofásica de 120 Vrms
## 1) **Dominio Comportamental**
### Requerimientos del Sistema

#### Requerimientos Funcionales
| Requerimiento                 | Descripción |
|--------------------------------|---------------------------------------------|
| **Medición de Tensión Pico (Vp)** | El sistema debe ser capaz de medir la tensión pico de una señal AC con un valor promedio de 120 Vrms. |
| **Conversión Analógica a Digital** | La señal analógica de entrada debe ser convertida a una señal digital para su procesamiento. |
| **Procesamiento Digital** | El sistema debe procesar la señal digital para calcular el valor de la tensión pico. |
| **Visualización** | El valor de la tensión pico debe ser mostrado en un visualizador digital, ya sea mediante displays de 7 segmentos o enviando los datos a una terminal serial. |

#### Requerimientos No Funcionales

| Requerimiento                 | Descripción |
|--------------------------------|---------------------------------------------|
| **Precisión** |  El sistema debe tener una precisión adecuada, considerando las pérdidas en el circuito analógico de acople. |
| **Velocidad de Respuesta** |  El sistema debe tener una precisión adecuada, considerando las pérdidas en el circuito analógico de acople. |
| **Seguridad** |  El sistema debe tener una precisión adecuada, considerando las pérdidas en el circuito analógico de acople. |
| **Facilidad de uso** | La interfaz de visualización debe ser clara y fácil de interpretar. |

### Entradas y salidas
1) Entradas 
* Señal analógica: Voltaje de la red eléctrica (120 Vrms)
* Clock: Necesario para el numero de veces que se actualiza el dato y frecuencia de muestreo del dispositivo

2) Salidas
* Señal digital: Datos generados por el ADC0808, representando la tensión pico.
* Visualización de datos: Display de 7 segmentos
  
## 2) Diagrama de flujo 


