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
  
### Diagrama de flujo 
![Representacion del comportamiento](./DiagramaLab3.png)

## 2) Dominio Estructural
### Diagrama de caja negra
![Diagrama](./CajaNegra.png)

### Diseño del circuito en compuertas lógicas


### Descripción del diseño en HDL

El codigo planteado para la realización del laboratorio se encuentra adjunto en la carpeta respectiva a la práctica 3. 
- En el módulo planteado se expresa el Clock del sistema; las entradas que lee la FPGA de conversor ADC; y las salidas para cada uno de los decodificadores BCD.
- Si se desea mapear 120 VRMS en 255 (entrada binaria), se debe realizar la división entre ambos valores para deducir cuánto voltaje equivale un único bit en la entrada. Este resultado se debe multiplicar por la lectura de la FPGA en los pines de entrada _bin_in_, y así obtener obtener en la salida la medición deseada. En el caso máximo, se multiplica 255 (bits de entrada = 5V) por 120, lo que requiere un registro de 15 bits (_mult_registro_) para almacenar el número. 

Posterior al escalado, la magnitud resultante puede oscilar en un rango entre 120 y 0, por lo que se almacena en forma binaria en un registro de 7 bits, para luego ser dividido en centenas, decenas, y unidades, y ser enviado a los decodificadores BCD. Los decodificadores convierten el número obtenido a base 10, y lo muestran en tiempo real en los _display 7 segmentos_.

## 3) Dominio Fisico
### Protocolo de Ensayo y Prueba

#### 1. Preparación del Entorno

##### Seguridad:
- Asegúrate de trabajar en un área bien ventilada y con espacio suficiente.
- Utiliza equipos de protección personal (EPP), como guantes aislantes y gafas de seguridad.
- Asegúrate de que la fuente de alimentación esté desconectada antes de realizar cualquier conexión.

##### Herramientas y Equipos:
- Multímetro para medir voltajes y corrientes.
- Osciloscopio para visualizar las señales analógicas.
- Fuente de alimentación de 120 Vrms (o un transformador reductor para pruebas seguras).
- FPGA o microcontrolador para implementar el sistema digital.
- Protoboard y cables de conexión.
- Componentes electrónicos (diodos, resistencias, condensadores, ADC0808, displays de 7 segmentos, etc.).

##### Documentación:
- Ten a mano el datasheet del ADC0808 y cualquier otro componente crítico.
- Revisa los diagramas esquemáticos y el código HDL antes de comenzar.

---

#### 2. Pruebas del Circuito Analógico de Acondicionamiento

##### Prueba del Rectificador:
- Conecta el rectificador de media onda o onda completa a la señal AC de 120 Vrms.
- Usa el osciloscopio para verificar que la señal rectificada tenga la forma esperada.
- Mide el voltaje de salida del rectificador con el multímetro.

##### Prueba del Filtro:
- Conecta el filtro (condensador) a la salida del rectificador.
- Verifica con el osciloscopio que la señal esté suavizada y tenga un voltaje DC estable.
- Mide el voltaje de salida del filtro con el multímetro.

##### Verificación de Pérdidas:
- Compara el voltaje de entrada (120 Vrms) con el voltaje de salida del circuito de acondicionamiento.
- Registra las pérdidas de voltaje (por ejemplo, 0.7 V en los diodos) para compensarlas en el procesamiento digital.

---

#### 3. Pruebas del ADC0808

##### Conexión del ADC:
- Conecta la señal acondicionada a la entrada del ADC0808.
- Asegúrate de que el ADC esté correctamente alimentado y que la señal de clock esté funcionando.

##### Verificación de la Conversión:
- Usa el osciloscopio para verificar que la señal de entrada al ADC esté dentro del rango permitido.
- Verifica que la salida digital del ADC (8 bits) corresponda al valor esperado de la señal analógica.

##### Prueba del Clock:
- Verifica que la señal de clock del ADC esté dentro de los parámetros especificados en el datasheet.
- Ajusta la frecuencia del clock si es necesario.

---

#### 4. Pruebas del Sistema Digital (FPGA o Microcontrolador)

##### Implementación del Procesamiento Digital:
- Carga el diseño HDL en la FPGA o el firmware en el microcontrolador.
- Verifica que el sistema digital reciba correctamente la señal digital del ADC.

##### Compensación de Pérdidas:
- Asegúrate de que el sistema digital compense las pérdidas registradas en el circuito analógico.
- Verifica que el valor de Vp calculado sea correcto.

##### Prueba de la Visualización:
- Conecta los displays de 7 segmentos o la terminal serial al sistema digital.
- Verifica que el valor de Vp se muestre correctamente en el visualizador.

---

#### 5. Pruebas Integrales del Sistema

##### Prueba con Diferentes Voltajes:
- Alimenta el sistema con diferentes voltajes AC (por ejemplo, 110 Vrms y 120 Vrms).
- Verifica que el sistema mida y muestre correctamente el valor de Vp en cada caso.

##### Prueba de Estabilidad:
- Deja el sistema funcionando durante un período prolongado (por ejemplo, 1 hora).
- Verifica que no haya sobrecalentamiento o fallos en los componentes.

##### Prueba de Seguridad:
- Verifica que no haya fugas de corriente o cortocircuitos en el circuito.
- Asegúrate de que el sistema se apague correctamente en caso de fallo.

---

#### 6. Documentación y Registro de Resultados

##### Registro de Mediciones:
- Registra los valores medidos en cada etapa (voltajes, señales digitales, etc.).
- Compara los resultados con los valores esperados.

##### Identificación de Errores:
- Si se detectan errores, documenta las posibles causas y las correcciones aplicadas.
- Realiza las modificaciones necesarias y repite las pruebas.

##### Informe Final:
- Prepara un informe que incluya:
  - Descripción del sistema.
  - Diagramas esquemáticos.
  - Resultados de las pruebas.
  - Conclusiones y recomendaciones.

---

#### 7. Video de Explicación (Opcional)

- Graba un video corto (máximo 5 minutos) explicando:
  - El flujo de diseño.
  - Las pruebas realizadas.
  - Los resultados obtenidos.
  - Las conclusiones finales.

---


- **Seguridad:** Siempre prioriza la seguridad al trabajar con altos voltajes. Si es posible, utiliza un transformador reductor para realizar pruebas iniciales con voltajes más bajos.
- **Iteración:** Si encuentras errores, repite las pruebas después de realizar las correcciones necesarias.
- **Documentación:** Mantén un registro detallado de todas las pruebas y resultados para facilitar la depuración y la mejora del sistema.

