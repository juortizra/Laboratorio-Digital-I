# Maquina de Estado del proyecto final

## Introducción

En el marco de los objetivos de desarrollo planteados por la organización de las naciones unidas, especificamente los objetivos de hambre cero y ciudades sostenibles, planteamos como proyecto un sistema digital de automatización y monitoreo de cultivos de tomates que esten sobre terrazas de edificos en la ciudad de Bogotá, como propuesta a aportar al desarrollo de estos objetivos. Para la implementación de dicho proyecto, se creo un prototipo en el que mediante un sensor capacitivo de humedad del suelo basado en el protocolo I2C (Soil sensor seesaw) se monitorea dicha variable, mostrandola en una pantalla LCD V1.4 16×2 con un modulo PCF8574 Integrado que tambien esta basada en ese mismo protocolo; además de usar esa infromación de humedad del suelo para controlar dicha variable con un sistema de riego, de manera que esta permaneceria dentro de un rango establecido que favorezca el buen desarrollo del cultivo. Debido a la complejidad del sistema y la numerosa cantidad de maquinas de estado que se manejan paralelamente, en este documento nos centraremos en el flujo de diseño para implementar la pantalla LCD en nuestro sistema.

![Diagrama](./Maquina11.png)


![Diagrama](./Maquina2.png)
