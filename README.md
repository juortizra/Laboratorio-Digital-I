# Sistema de riego para cultivos de tomate
## I. **Objetivo**
Desarrollar e implementar un sistema de riego automatizado basado en electrónica digital que emplee sensores de humedad para determinar el nivel de riego necesario, una FPGA para el procesamiento y toma de decisiones, y actuadores como mini bombas para la distribución del agua; con la finalidad de obtener un monitoreo y control eficiente de cultivos de tomate, optimizando el uso del agua y asegurando condiciones óptimas para el crecimiento de las plantas. 
## II. **Solución**
Como solución se desarrolló un sistema de riego automatizado basado en una FPGA, que implemente el protocolo de comunicación I2C para la lectura de un sensor digital de humedad del suelo, para facilitar el monitoreo, optimización y activación en el riego de una planta de tomate por medio de una mini bomba de agua. Se integro una pantalla LCD para la visualización de datos, y luces Led indicando el funcionamiento del dispositivo.\
En el desarrollo del proyecto se analizaron dos enfoques distintos como solución para la problemática planteada. En el primer enfoque se propone la automatización de un cultivo basada en una red de sensores para monitorear 3 variables distintas en tiempo real, estos datos serian procesados en la FPGA, la cual regula los actuadores necesarios para mantener las condiciones óptimas de crecimiento. En esta solución podemos ver una perspectiva más general con un control integral del ambiente dadas las variables controladas.
Por otro lado, la solución finalmente implementada se centra en la automatización del riego utilizando una FPGA con el protocolo de comunicación I2C para la lectura de un sensor digital de humedad del suelo. A diferencia del primer enfoque, este sistema está diseñado específicamente para optimizar la irrigación, teniendo como actuador una mini bomba de agua que se activa cuando se detectan niveles inadecuados de humedad en el suelo. Adicionalmente, se incorporó una pantalla LCD para la visualización de datos y luces LED como indicadores del funcionamiento del dispositivo, brindando una interfaz más accesible para el monitoreo del sistema.
En términos de comparación, la primera solución planteada ofrece un monitoreo mas amplio al incluir múltiples sensores y permitir una regulación de distintos factores dados en los entornos del cultivo, en contraste, la solución final presenta sistemas más específicos, prácticos y optimizados para el sistema de riego automatizado, esto permite una comunicación mas eficiente y confiable con la FPGA. Además, la incorporación de la interfaz visual permite un análisis y comprensión más sencillo y efectivo de la variable utilizada.
## III. **Estructura de la Solución**
## IV. **Tamaño de la Solución**
## V. **Desafios**
| Semana | Fechas                  | Actividad Principal                         |
|--------|-------------------------|---------------------------------------------|
| 1      |   2/12/2024 - 6/12/2024     | Investigación y planeación de componentes |
| 2 - 3  |   9/12/2024 - 20/12/2024    | Configuración de sensores                 |
| 4 - 5  |   13/01/2025 - 24/01/2025   | Programación y recopilación de datos en la FPGA |
| 6      |   27/01/2025 - 31/01/2025   | Configuración de actuadores               |
| 7      |   3/02/2025 - 7/02/2025     | Integración de todo el sistema y pruebas finales |
| 8      |   10/02/2025 - 14/02/2025   | Presentación del documento y proyecto final
## VI. **Conclusiones**
## VII. **Trabajos futuros**
